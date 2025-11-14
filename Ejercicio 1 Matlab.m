%% ==============================================================
%  escenario1_best_effort_sin_qos.m
%
%  ESCENARIO 1 (ERROR):
%  "Todo Best Effort, sin QoS, casi sin Q-in-Q"
%
%  - Red Metro Ethernet que transporta servicios triple-play:
%      * Voz (VoIP)
%      * Vídeo (IPTV)
%      * Datos (Internet)
%  - El enlace de salida está CONGESTIONADO (capacidad insuficiente).
%  - NO se aplica QoS (no hay priorización):
%      * Todos los servicios se tratan igual (Best Effort).
%  - Casi sin Q-in-Q:
%      * Podemos imaginar que todo va dentro de UNA única VLAN
%        de servicio (S-VLAN) del operador.
%      * No diferenciamos C-VLAN ni PCP. Es como si todo fuera
%        tráfico "genérico" dentro del Metro Ethernet.
%
%  OBJETIVO DEL ESCENARIO:
%    Demostrar el ERROR de no aplicar QoS:
%      - La voz (VoIP) sufre colas y pérdidas similares
%        al resto de servicios cuando hay congestión.
%      - No se garantizan ni retardo ni pérdida baja para la voz.
%
%  Este script:
%    1) Simula el tráfico de voz, vídeo y datos llegando a un
%       enlace compartido congestionado.
%    2) Modela un único buffer de salida compartido.
%    3) Aplica una política de servicio Best Effort (sin prioridad).
%    4) Calcula colas, throughput y descartes.
%    5) Dibuja varias gráficas para analizar el comportamiento.
%
%  NOTA:
%    No es una simulación de paquetes Ethernet "reales" (bit a bit),
%    sino un modelo de colas a nivel de bytes/tasa de tráfico,
%    suficiente para explicar conceptos de QoS.
%
%  Autor: ChatGPT (adaptado para docencia)
% ==============================================================

clear; clc; close all;

%% ------------------ PARÁMETROS GENERALES DE SIMULACIÓN ------------------

% Duración total de la simulación [segundos].
% Elegimos un valor moderado para poder ver bien la dinámica de colas.
Tsim = 10;   % 10 segundos

% Paso de tiempo de la simulación [segundos].
% Cuanto menor sea dt:
%   - Más precisa la simulación.
%   - Más iteraciones (más carga de cómputo).
dt = 1e-3;   % 1 ms

% Número total de pasos o iteraciones del bucle de simulación.
N = round(Tsim / dt);

% Vector de tiempo para usar en las gráficas (desde 0 hasta Tsim - dt).
t = (0:N-1) * dt;

% Capacidad del enlace Metro Ethernet [bits/s].
% ERROR QUE QUEREMOS DEMOSTRAR:
%   La suma de tasas ofrecidas será MAYOR que esta capacidad,
%   para forzar congestión y ver el problema sin QoS.
%
% Servicios:
%   - Voz:   2 Mbps
%   - Vídeo: 20 Mbps
%   - Datos: 10 Mbps
%   ----------------------------
%   Suma:   32 Mbps > capacidad (por ej. 20 Mbps)
%
C_bps = 20e6;   % 20 Mbps (capacidad insuficiente frente a 32 Mbps ofrecidos)

% Capacidad del enlace por intervalo de tiempo dt, en BYTES por "slot".
% C_bytes_slot = (bits por segundo) * (segundos) / (8 bits por byte).
C_bytes_slot = C_bps * dt / 8;

% Tamaño total del buffer de salida [bytes].
% Este buffer se comparte ENTRE todos los servicios (voz, vídeo, datos).
% Si se llena, los bytes que lleguen de más se DESCARTAN (pérdida).
buffer_total_bytes = 2e6;   % 2 MBytes de cola total


%% ------------------ "Casi sin Q-in-Q": configuración VLAN ---------------
% En una red real Metro Ethernet con Q-in-Q:
%   - Hay una S-VLAN (outer VLAN) del operador.
%   - Cada servicio/hogar podría tener su propia C-VLAN (inner VLAN).
%
% En ESTE escenario erróneo:
%   - Imaginamos que todo el tráfico va dentro de UNA sola S-VLAN.
%   - No usamos C-VLAN para diferenciar servicios.
%   - No se usa PCP (prioridad) ni QoS.
%
% Esto equivale a "casi sin Q-in-Q" desde el punto de vista de QoS:
%   - La red tiene la capacidad de encapsular, pero en la práctica
%     trata todo el tráfico igual.

S_VLAN_ID = 100;  % Única VLAN de servicio del operador

% No definimos C-VLAN ni PCP porque NO se usan en este escenario.
% (Esto es precisamente parte del "error" que queremos ilustrar).


%% ------------------ DEFINICIÓN DE SERVICIOS TRIPLE-PLAY -----------------
% Definimos 3 servicios:
%   1) Voz (VoIP)
%   2) Vídeo (IPTV)
%   3) Datos (Internet / Best Effort)
%
% Para cada servicio, definimos:
%   - rate_bps   : tasa media de generación [bits/s].
%   - pkt_size   : tamaño "típico" de paquete [bytes] (sólo decorativo).
%   - var_rel    : variación relativa de la tasa (para dar realismo).
%
% Importante:
%   La suma de tasas será MAYOR que la capacidad del enlace,
%   para provocar congestión y ver el problema sin QoS.

NUM_SERV = 3;   % número de servicios (voz, vídeo, datos)

% CONSTANTES para acceder por nombre en vez de por número.
VOICE = 1;
VIDEO = 2;
DATA  = 3;

% Creamos un array de estructuras para los servicios.
servicios(NUM_SERV) = struct();

% --------------------- Servicio de VOZ (VoIP) ----------------------------
servicios(VOICE).nombre   = 'Voz (VoIP)';
servicios(VOICE).rate_bps = 2e6;      % 2 Mbps de tráfico de voz
servicios(VOICE).pkt_size = 200;      % 200 bytes, paquetes pequeños
% Variación relativa de la tasa (poca, la voz suele ser casi CBR).
servicios(VOICE).var_rel  = 0.05;     % 5% de variación

% --------------------- Servicio de VÍDEO (IPTV) --------------------------
servicios(VIDEO).nombre   = 'Vídeo (IPTV)';
servicios(VIDEO).rate_bps = 20e6;     % 20 Mbps de vídeo (ej. un canal HD)
servicios(VIDEO).pkt_size = 1400;     % 1400 bytes, paquetes grandes
% Variación relativa de la tasa (moderada).
servicios(VIDEO).var_rel  = 0.20;     % 20% de variación

% --------------------- Servicio de DATOS (Internet) ----------------------
servicios(DATA).nombre    = 'Datos (Internet)';
servicios(DATA).rate_bps  = 10e6;     % 10 Mbps de tráfico de datos
servicios(DATA).pkt_size  = 1000;     % 1000 bytes, tamaño intermedio
% Variación relativa (alta, para simular tráfico "bursty").
servicios(DATA).var_rel   = 0.50;     % 50% de variación


%% ------------------ ESTRUCTURAS PARA GUARDAR RESULTADOS -----------------
% Cola por servicio en cada instante de tiempo:
%   queue_bytes(serv, k) = bytes en cola del servicio "serv" en el instante k.
queue_bytes = zeros(NUM_SERV, N);

% Bytes transmitidos TOTAL acumulados por servicio en todo Tsim.
tx_bytes = zeros(1, NUM_SERV);

% Bytes descartados TOTAL acumulados por servicio (por cola llena).
drop_bytes = zeros(1, NUM_SERV);

% Bytes transmitidos en cada intervalo dt (para throughput instantáneo).
tx_slot = zeros(NUM_SERV, N);

% Bytes descartados en cada intervalo dt (para ver picos de pérdida).
drop_slot = zeros(NUM_SERV, N);


%% ------------------ VARIABLES DE ESTADO DE LA COLA ----------------------
% cola_actual(serv) = bytes en cola del servicio en el instante actual.
cola_actual = zeros(1, NUM_SERV);

% buffer_ocupado = suma de todas las colas (bytes actualmente en el buffer).
buffer_ocupado = 0;


%% ====================== BUCLE PRINCIPAL DE SIMULACIÓN ===================

fprintf('Simulando ESCENARIO 1: Best Effort, sin QoS, S-VLAN única=%d ...\n', S_VLAN_ID);

for k = 1:N
    
    % ==============================================================
    % 1) GENERACIÓN DE TRÁFICO (LLEGADAS A LA COLA)
    % --------------------------------------------------------------
    % En cada intervalo dt, cada servicio genera cierta cantidad
    % de bytes, basada en su tasa media y variabilidad.
    % Estos bytes INTENTAN entrar en el buffer de salida.
    % Si no hay espacio suficiente, se descartan.
    % ==============================================================
    
    % "llegadas(s)" almacenará cuántos bytes genera e intenta encolar
    % el servicio s en este intervalo dt.
    llegadas = zeros(1, NUM_SERV);
    
    for s = 1:NUM_SERV
        
        % Tasa media de generación de ese servicio [bits/s].
        R = servicios(s).rate_bps;
        
        % Variación relativa de la tasa (p.ej. 0.2 => ±20%).
        var_rel = servicios(s).var_rel;
        
        % Generamos un factor aleatorio multiplicativo:
        %   factor_aleatorio ~ N(1, var_rel^2),
        %   es decir, media 1, desviación var_rel.
        factor_aleatorio = 1 + var_rel * randn;
        
        % Si por azar sale negativo, lo truncamos a 0 (no puede ser negativo).
        if factor_aleatorio < 0
            factor_aleatorio = 0;
        end
        
        % Cálculo de bytes generados:
        %   (R bits/seg) * (dt seg) / (8 bits/byte) * factor_aleatorio.
        bytes_generados = (R * factor_aleatorio) * dt / 8;
        
        % Redondeamos al entero más cercano.
        bytes_generados = round(bytes_generados);
        
        % Guardamos en el vector de llegadas.
        llegadas(s) = bytes_generados;
    end
    
    
    % ==============================================================
    % 2) INSERCIÓN EN EL BUFFER / DESCARTE POR COLA LLENA
    % --------------------------------------------------------------
    % Tenemos un ÚNICO buffer compartido de tamaño "buffer_total_bytes".
    % La suma de colas de todos los servicios no puede superar esa capacidad.
    % Si llegan bytes y no hay espacio suficiente, se DESCARTAN.
    % ==============================================================
    
    for s = 1:NUM_SERV
        if llegadas(s) > 0
            % Comprobamos si cabe TODO lo que llega.
            if buffer_ocupado + llegadas(s) <= buffer_total_bytes
                % Cabe todo -> se encola íntegramente.
                cola_actual(s) = cola_actual(s) + llegadas(s);
                buffer_ocupado = buffer_ocupado + llegadas(s);
            else
                % No cabe todo: calculamos cuánto espacio queda libre.
                espacio_libre = buffer_total_bytes - buffer_ocupado;
                
                if espacio_libre > 0
                    % Se acepta sólo lo que cabe. El resto se descarta.
                    cola_actual(s) = cola_actual(s) + espacio_libre;
                    buffer_ocupado = buffer_ocupado + espacio_libre;
                    
                    descartado = llegadas(s) - espacio_libre;
                    drop_bytes(s)    = drop_bytes(s) + descartado;
                    drop_slot(s, k)  = drop_slot(s, k) + descartado;
                else
                    % El buffer está totalmente lleno -> se descarta todo.
                    descartado = llegadas(s);
                    drop_bytes(s)    = drop_bytes(s) + descartado;
                    drop_slot(s, k)  = drop_slot(s, k) + descartado;
                end
            end
        end
    end
    
    
    % ==============================================================
    % 3) SERVICIO DEL ENLACE (SALIDA) - POLÍTICA Best Effort
    % --------------------------------------------------------------
    % El enlace puede transmitir como máximo C_bytes_slot bytes en
    % este intervalo dt. Vamos a repartir esa capacidad de forma
    % proporcional al volumen de datos en cola de cada servicio.
    %
    % Esto simula un servicio Best Effort:
    %   - No hay prioridad.
    %   - Todos compiten en función de su presencia en la cola.
    % ==============================================================
    
    % Capacidad restante que puede transmitir el enlace en este dt.
    capacidad_restante = C_bytes_slot;
    
    % Cálculo del total en cola.
    total_en_cola = sum(cola_actual);
    
    if total_en_cola > 0
        % Repartimos la capacidad según el porcentaje de cola de cada servicio.
        for s = 1:NUM_SERV
            
            % Porcentaje de cola de este servicio frente al total.
            proporcion = cola_actual(s) / total_en_cola;
            
            % Capacidad que "teóricamente" le corresponde a este servicio.
            bytes_a_servir = proporcion * C_bytes_slot;
            
            % No podemos servir más de lo que hay en cola.
            bytes_a_servir = min(bytes_a_servir, cola_actual(s));
            
            % Redondeamos hacia abajo para evitar fracciones.
            bytes_a_servir = floor(bytes_a_servir);
            
            % Actualizamos cola, buffer y contadores SOLO si hay algo que servir.
            if bytes_a_servir > 0
                cola_actual(s)   = cola_actual(s) - bytes_a_servir;
                buffer_ocupado   = buffer_ocupado - bytes_a_servir;
                tx_bytes(s)      = tx_bytes(s) + bytes_a_servir;
                tx_slot(s, k)    = tx_slot(s, k) + bytes_a_servir;
                capacidad_restante = capacidad_restante - bytes_a_servir;
            end
        end
    end
    
    
    % ==============================================================
    % 4) GUARDAR EL ESTADO DE LA COLA PARA ESTE INSTANTE
    % --------------------------------------------------------------
    % Guardamos el número de bytes en cola de cada servicio en el
    % instante k, para poder luego dibujar las gráficas.
    % ==============================================================
    
    queue_bytes(:, k) = cola_actual(:);
    
end  % fin del bucle de tiempo k


%% ====================== CÁLCULO DE MÉTRICAS GLOBALES ====================

% Throughput medio por servicio [bps].
throughput_bps = zeros(1, NUM_SERV);

% Probabilidad aproximada de descarte (porcentaje de bytes descartados).
prob_desc = zeros(1, NUM_SERV);

for s = 1:NUM_SERV
    % Throughput medio:
    %   (bytes transmitidos * 8) / Tsim [bits/s].
    throughput_bps(s) = (tx_bytes(s) * 8) / Tsim;
    
    % Bytes generados aproximados:
    %   tasa media * tiempo / 8. (No tiene en cuenta la variación, pero
    %   nos sirve para estimar el porcentaje de descartes).
    bytes_generados_aprox = servicios(s).rate_bps * Tsim / 8;
    
    % Probabilidad (aproximada) de descarte.
    prob_desc(s) = drop_bytes(s) / bytes_generados_aprox;
end


%% ======================== GRÁFICAS E INTERPRETACIÓN =====================

% Colores para las trazas (simplemente estética).
col_voice = [0 0.447 0.741];     % azul
col_video = [0.8500 0.3250 0.0980]; % rojo/naranja
col_data  = [0.4660 0.6740 0.1880]; % verde

% ------------------------ 1) Colas por servicio --------------------------
figure;
subplot(3,1,1);
plot(t, queue_bytes(VOICE, :), 'Color', col_voice, 'LineWidth', 1.2);
grid on;
title('ESCENARIO 1 - Best Effort, sin QoS (S-VLAN única)');
ylabel('Cola Voz [bytes]');

subplot(3,1,2);
plot(t, queue_bytes(VIDEO, :), 'Color', col_video, 'LineWidth', 1.2);
grid on;
ylabel('Cola Vídeo [bytes]');

subplot(3,1,3);
plot(t, queue_bytes(DATA, :), 'Color', col_data, 'LineWidth', 1.2);
grid on;
ylabel('Cola Datos [bytes]');
xlabel('Tiempo [s]');

% ------------------------ 2) Ocupación del buffer (área apilada) ---------
% Calculamos qué porcentaje del buffer ocupa cada servicio en cada instante.
colas_norm = (queue_bytes.' / buffer_total_bytes) * 100;  % N x 3 (%)

figure;
area(t, colas_norm);
grid on;
title('Ocupación relativa del buffer por servicio (Best Effort, sin QoS)');
xlabel('Tiempo [s]');
ylabel('Ocupación buffer [%]');
legend({servicios(VOICE).nombre, servicios(VIDEO).nombre, servicios(DATA).nombre}, ...
       'Location', 'northwest');

% ------------------------ 3) Throughput instantáneo suavizado ------------
% Calculamos el throughput instantáneo:
%   th_inst(s, k) = tx_slot(s, k) * 8 / (dt * 1e6) [Mbps].
% y lo suavizamos con una media móvil para que la gráfica se vea mejor.

ventana_suav = 200;  % ventana de media móvil (200 muestras ~ 0.2 s)
b = ones(ventana_suav,1) / ventana_suav;  % coeficientes del filtro

figure;
for s = 1:NUM_SERV
    subplot(3,1,s);
    
    % Throughput instantáneo en Mbps.
    th_inst = tx_slot(s, :) * 8 / (dt * 1e6);
    
    % Suavizado con media móvil.
    th_suav = filter(b, 1, th_inst);
    
    plot(t, th_suav, 'LineWidth', 1.2);
    grid on;
    
    if s == VOICE
        titulo_serv = 'Voz (VoIP)';
    elseif s == VIDEO
        titulo_serv = 'Vídeo (IPTV)';
    else
        titulo_serv = 'Datos (Internet)';
    end
    
    title(['Throughput instantáneo suavizado - ', titulo_serv]);
    ylabel('Throughput [Mbps]');
    if s == DATA
        xlabel('Tiempo [s]');
    end
end

% ------------------------ 4) Barras: Thpt medio y descarte ---------------
th_mbps = throughput_bps / 1e6;   % pasamos a Mbps
desc_pct = prob_desc * 100;       % pasamos a %

figure;

subplot(1,2,1);
bar(th_mbps);
set(gca, 'XTickLabel', {servicios.nombre});
ylabel('Throughput medio [Mbps]');
title('Throughput medio por servicio (Best Effort)');
grid on;

subplot(1,2,2);
bar(desc_pct);
set(gca, 'XTickLabel', {servicios.nombre});
ylabel('Descartes [% aprox]');
title('Porcentaje aproximado de descarte por servicio');
grid on;


%% ------------------------ 5) RESUMEN EN CONSOLA -------------------------
fprintf('\n================== RESULTADOS ESCENARIO 1 ==================\n');
fprintf('Config: Best Effort, sin QoS, S-VLAN única=%d (sin C-VLAN / sin PCP)\n\n', S_VLAN_ID);

for s = 1:NUM_SERV
    fprintf('Servicio: %-15s | Thpt = %6.2f Mbps | Descarte aprox = %5.2f %%\n', ...
        servicios(s).nombre, ...
        th_mbps(s), ...
        desc_pct(s));
end

fprintf('\nInterpretación del ESCENARIO 1 (para explicar al profesor):\n');
fprintf(' - Se simula un enlace Metro Ethernet congestionado que transporta voz,\n');
fprintf('   vídeo y datos, todos mezclados dentro de una única VLAN de servicio.\n');
fprintf(' - No se aplica ninguna política de QoS ni de prioridad: todos los\n');
fprintf('   servicios compiten de forma Best Effort.\n');
fprintf(' - Como la capacidad del enlace (20 Mbps) es menor que la suma de las\n');
fprintf('   tasas ofrecidas (32 Mbps), se generan colas largas y pérdidas en los\n');
fprintf('   tres servicios.\n');
fprintf(' - La voz (VoIP) NO recibe un tratamiento preferente y sufre colas y\n');
fprintf('   descartes comparables a los de vídeo y datos, lo que en una red real\n');
fprintf('   implicaría mala calidad de voz (cortes, retardos, etc.).\n');
fprintf(' - Este escenario sirve para ilustrar el ERROR de no aplicar QoS en un\n');
fprintf('   entorno triple-play: la red Metro Ethernet no asegura la calidad de\n');
fprintf('   la voz ni del vídeo cuando hay congestión.\n\n');


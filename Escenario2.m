%% ESCENARIO 2: Triple Play con QoS y Q-in-Q
% Simulación de tráfico VoIP, IPTV y Datos con priorización

clear; clc; close all;

% Parámetros de simulación
tiempo_simulacion = 10; % segundos
capacidad_enlace = 100; % Mbps
carga_red = 1.2; % Factor de congestión (>1 = congestionada)

% Trafico ofrecido por cada servicio (Mbps)
trafico_VoIP = 15;  % Voz
trafico_IPTV = 40;  % Video
trafico_Datos = 65; % Datos
trafico_total = trafico_VoIP + trafico_IPTV + trafico_Datos;

% Aplicar congestión
trafico_total_congestionado = trafico_total * carga_red;

% Capacidad asignada con QoS (Voz > Video > Datos)
capacidad_VoIP = min(trafico_VoIP * carga_red, capacidad_enlace * 0.3); % Máximo 30% para voz
capacidad_restante = capacidad_enlace - capacidad_VoIP;

capacidad_IPTV = min(trafico_IPTV * carga_red, capacidad_restante * 0.6); % 60% del resto para video
capacidad_Datos = capacidad_enlace - capacidad_VoIP - capacidad_IPTV; % El resto para datos

% Calcular trafico perdido
perdido_VoIP = max(0, trafico_VoIP * carga_red - capacidad_VoIP);
perdido_IPTV = max(0, trafico_IPTV * carga_red - capacidad_IPTV);
perdido_Datos = max(0, trafico_Datos * carga_red - capacidad_Datos);

% Throughput efectivo
throughput_VoIP = (trafico_VoIP * carga_red) - perdido_VoIP;
throughput_IPTV = (trafico_IPTV * carga_red) - perdido_IPTV;
throughput_Datos = (trafico_Datos * carga_red) - perdido_Datos;

% Retardo y jitter (simulación simplificada)
retardo_VoIP = 0.02 + 0.005 * (trafico_total_congestionado / capacidad_enlace); % segundos
retardo_IPTV = 0.03 + 0.01 * (trafico_total_congestionado / capacidad_enlace);
retardo_Datos = 0.05 + 0.05 * (trafico_total_congestionado / capacidad_enlace);

jitter_VoIP = 0.001 * (trafico_total_congestionado / capacidad_enlace);
jitter_IPTV = 0.002 * (trafico_total_congestionado / capacidad_enlace);
jitter_Datos = 0.01 * (trafico_total_congestionado / capacidad_enlace);

% Mostrar resultados
fprintf('=== ESCENARIO 2: Triple Play con QoS y Q-in-Q ===\n');
fprintf('Capacidad total del enlace: %.1f Mbps\n', capacidad_enlace);
fprintf('Trafico total ofrecido: %.1f Mbps\n', trafico_total_congestionado);
fprintf('Factor de congestión: %.1f\n\n', carga_red);

fprintf('--- Throughput (Mbps) ---\n');
fprintf('VoIP:  %.1f\n', throughput_VoIP);
fprintf('IPTV:  %.1f\n', throughput_IPTV);
fprintf('Datos: %.1f\n\n', throughput_Datos);

fprintf('--- Trafico perdido (Mbps) ---\n');
fprintf('VoIP:  %.1f\n', perdido_VoIP);
fprintf('IPTV:  %.1f\n', perdido_IPTV);
fprintf('Datos: %.1f\n\n', perdido_Datos);

fprintf('--- Retardo (ms) ---\n');
fprintf('VoIP:  %.1f\n', retardo_VoIP * 1000);
fprintf('IPTV:  %.1f\n', retardo_IPTV * 1000);
fprintf('Datos: %.1f\n\n', retardo_Datos * 1000);

fprintf('--- Jitter (ms) ---\n');
fprintf('VoIP:  %.2f\n', jitter_VoIP * 1000);
fprintf('IPTV:  %.2f\n', jitter_IPTV * 1000);
fprintf('Datos: %.2f\n\n', jitter_Datos * 1000);

% Gráficas
servicios = {'VoIP', 'IPTV', 'Datos'};

figure('Position', [100, 100, 1200, 800]);

% Gráfica 1: Throughput comparativo
subplot(2, 3, 1);
throughput = [throughput_VoIP, throughput_IPTV, throughput_Datos];
bar(throughput, 'FaceColor', [0.2, 0.6, 0.8]);
title('Throughput por Servicio');
ylabel('Mbps');
set(gca, 'XTickLabel', servicios);
grid on;

% Gráfica 2: Trafico perdido
subplot(2, 3, 2);
perdido = [perdido_VoIP, perdido_IPTV, perdido_Datos];
bar(perdido, 'FaceColor', [0.8, 0.2, 0.2]);
title('Trafico Perdido');
ylabel('Mbps');
set(gca, 'XTickLabel', servicios);
grid on;

% Gráfica 3: Retardo
subplot(2, 3, 3);
retardos = [retardo_VoIP, retardo_IPTV, retardo_Datos] * 1000;
bar(retardos, 'FaceColor', [0.9, 0.6, 0.2]);
title('Retardo por Servicio');
ylabel('ms');
set(gca, 'XTickLabel', servicios);
grid on;

% Gráfica 4: Jitter
subplot(2, 3, 4);
jitters = [jitter_VoIP, jitter_IPTV, jitter_Datos] * 1000;
bar(jitters, 'FaceColor', [0.6, 0.4, 0.8]);
title('Jitter por Servicio');
ylabel('ms');
set(gca, 'XTickLabel', servicios);
grid on;

% Gráfica 5: Capacidad asignada vs Utilizada
subplot(2, 3, 5);
capacidad_asignada = [capacidad_VoIP, capacidad_IPTV, capacidad_Datos];
trafico_ofrecido = [trafico_VoIP*carga_red, trafico_IPTV*carga_red, trafico_Datos*carga_red];
bar([trafico_ofrecido; capacidad_asignada]', 'grouped');
title('Trafico Ofrecido vs Capacidad Asignada');
ylabel('Mbps');
legend('Ofrecido', 'Asignado', 'Location', 'northwest');
set(gca, 'XTickLabel', servicios);
grid on;

% Gráfica 6: Utilización del enlace
subplot(2, 3, 6);
utilizacion = [throughput_VoIP, throughput_IPTV, throughput_Datos] / capacidad_enlace * 100;
pie(utilizacion, servicios);
title('Utilización del Enlace por Servicio');

sgtitle('Escenario 2: Triple Play con QoS y Q-in-Q - Análisis de Rendimiento');

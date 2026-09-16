%% 星座图绘制函数
% 功能: 绘制BPSK信号的星座图,用于评估解调质量
%
% 输入参数:
%   symbols - 符号序列 (复数)
%   title_str - 图表标题
%   fig_number - 图号
%
% 输出: 绘制星座图

function plot_constellation(symbols, title_str, fig_number)
    % 默认参数
    if nargin < 2
        title_str = 'Constellation Diagram';
    end
    if nargin < 3
        fig_number = 1;
    end
    
    figure(fig_number);
    clf;
    
    % 提取I和Q分量
    I = real(symbols);
    Q = imag(symbols);
    
    % 绘制散点图
    scatter(I, Q, 20, 'b', 'filled', 'MarkerFaceAlpha', 0.5);
    hold on;
    
    % 添加参考点 (BPSK的两个星座点)
    scatter([-1, 1], [0, 0], 100, 'r', 'x', 'LineWidth', 2);
    
    % 设置图表属性
    grid on;
    axis equal;
    xlabel('I (In-phase)');
    ylabel('Q (Quadrature)');
    title(title_str);
    
    % 设置坐标范围
    axis([-2 2 -2 2]);
    
    % 添加图例
    legend('接收符号', '理想星座点', 'Location', 'best');
    
    % 计算性能指标
    % EVM (误差向量幅度)
    ideal_symbols = sign(I) + 1j * sign(Q);
    error_vector = symbols - ideal_symbols;
    evm = sqrt(mean(abs(error_vector).^2)) / sqrt(mean(abs(ideal_symbols).^2)) * 100;
    
    % 在图表上显示EVM
    text(0.05, 0.95, sprintf('EVM = %.2f%%', evm), ...
        'Units', 'normalized', 'VerticalAlignment', 'top', ...
        'BackgroundColor', 'yellow', 'EdgeColor', 'black');
    
    % 设置字体大小
    set(gca, 'FontSize', 12);
    
end

%% 高级星座图显示函数
% 功能: 绘制带有密度显示和统计信息的星座图
%
% 输入参数:
%   tx_symbols - 发送符号
%   rx_symbols - 接收符号
%   title_str - 图表标题
%   fig_number - 图号

function plot_constellation_advanced(tx_symbols, rx_symbols, title_str, fig_number)
    % 默认参数
    if nargin < 3
        title_str = 'Advanced Constellation Diagram';
    end
    if nargin < 4
        fig_number = 1;
    end
    
    figure(fig_number);
    clf;
    
    % 提取I和Q分量
    I_rx = real(rx_symbols);
    Q_rx = imag(rx_symbols);
    I_tx = real(tx_symbols);
    Q_tx = imag(tx_symbols);
    
    % 使用hexbin或密度散点图
    % 这里使用scatter配合透明度显示密度
    scatter(I_rx, Q_rx, 20, 'b', 'filled', 'MarkerFaceAlpha', 0.3);
    hold on;
    
    % 绘制理想星座点
    scatter([-1, 1], [0, 0], 200, 'r', 'x', 'LineWidth', 3, 'DisplayName', '理想星座点');
    
    % 绘制圆圈表示决策区域
    circle_x = linspace(-1, 1, 100);
    circle_y_upper = sqrt(max(0, 1 - circle_x.^2));
    circle_y_lower = -circle_y_upper;
    
    % 绘制决策边界 (中垂线)
    plot([0, 0], [-2, 2], 'k--', 'LineWidth', 2, 'DisplayName', '决策边界');
    
    % 设置图表属性
    grid on;
    axis equal;
    xlabel('I (In-phase)', 'FontSize', 12);
    ylabel('Q (Quadrature)', 'FontSize', 12);
    title(title_str, 'FontSize', 14, 'FontWeight', 'bold');
    
    % 设置坐标范围
    axis([-2 2 -2 2]);
    
    % 计算性能指标
    % 误差向量幅度 (EVM)
    ideal_rx = sign(I_rx) + 1j * sign(Q_rx);
    error_vector = rx_symbols - ideal_rx;
    evm = sqrt(mean(abs(error_vector).^2)) / sqrt(mean(abs(ideal_rx).^2)) * 100;
    
    % 误比特率 (BER) 估计
    ber = sum(sign(I_rx) ~= sign(I_tx)) / length(I_tx);
    
    % 平均功率
    avg_power = mean(abs(rx_symbols).^2);
    
    % 在图表上显示信息
    info_text = sprintf(['EVM = %.2f%%\nBER = %.4f\nAvg Power = %.4f'], ...
        evm, ber, avg_power);
    text(0.02, 0.98, info_text, 'Units', 'normalized', ...
        'VerticalAlignment', 'top', 'BackgroundColor', 'lightyellow', ...
        'EdgeColor', 'black', 'FontSize', 11);
    
    legend('Location', 'best', 'FontSize', 10);
    set(gca, 'FontSize', 11);
    
end

%% 多子图星座图显示
% 功能: 显示处理前后的信号星座图对比
%
% 输入参数:
%   rx_raw - 原始接收信号
%   rx_after_carrier - 载波恢复后的信号
%   rx_after_sync - 符号同步后的信号
%   rx_equalized - 均衡后的信号

function plot_constellation_comparison(rx_raw, rx_after_carrier, rx_after_sync, rx_equalized)
    
    figure('Position', [100, 100, 1200, 800]);
    
    % 第一个子图: 原始信号
    subplot(2, 2, 1);
    scatter(real(rx_raw), imag(rx_raw), 20, 'b', 'filled', 'MarkerFaceAlpha', 0.5);
    hold on;
    scatter([-1, 1], [0, 0], 100, 'r', 'x', 'LineWidth', 2);
    grid on;
    axis equal;
    axis([-2 2 -2 2]);
    xlabel('I');
    ylabel('Q');
    title('原始接收信号');
    
    % 第二个子图: 载波恢复后
    subplot(2, 2, 2);
    scatter(real(rx_after_carrier), imag(rx_after_carrier), 20, 'g', 'filled', 'MarkerFaceAlpha', 0.5);
    hold on;
    scatter([-1, 1], [0, 0], 100, 'r', 'x', 'LineWidth', 2);
    grid on;
    axis equal;
    axis([-2 2 -2 2]);
    xlabel('I');
    ylabel('Q');
    title('载波恢复后的信号');
    
    % 第三个子图: 符号同步后
    subplot(2, 2, 3);
    scatter(real(rx_after_sync), imag(rx_after_sync), 20, 'c', 'filled', 'MarkerFaceAlpha', 0.5);
    hold on;
    scatter([-1, 1], [0, 0], 100, 'r', 'x', 'LineWidth', 2);
    grid on;
    axis equal;
    axis([-2 2 -2 2]);
    xlabel('I');
    ylabel('Q');
    title('符号同步后的信号');
    
    % 第四个子图: 均衡后
    subplot(2, 2, 4);
    scatter(real(rx_equalized), imag(rx_equalized), 20, 'm', 'filled', 'MarkerFaceAlpha', 0.5);
    hold on;
    scatter([-1, 1], [0, 0], 100, 'r', 'x', 'LineWidth', 2);
    grid on;
    axis equal;
    axis([-2 2 -2 2]);
    xlabel('I');
    ylabel('Q');
    title('信道均衡后的信号');
    
    sgtitle('BPSK 解调过程星座图对比', 'FontSize', 14, 'FontWeight', 'bold');
    
end

%% 计算并显示解调性能指标
% 功能: 计算EVM、BER等性能指标
%
% 输入参数:
%   tx_symbols - 发送符号
%   rx_symbols - 接收符号
%
% 输出:
%   metrics - 包含各种性能指标的结构体

function metrics = calculate_demodulation_metrics(tx_symbols, rx_symbols)
    
    % 确保长度相同
    N = min(length(tx_symbols), length(rx_symbols));
    tx = tx_symbols(1:N);
    rx = rx_symbols(1:N);
    
    % 1. 误差向量幅度 (EVM)
    error_vector = rx - tx;
    evm_linear = sqrt(mean(abs(error_vector).^2) / mean(abs(tx).^2));
    evm_db = 20 * log10(evm_linear);
    evm_percent = evm_linear * 100;
    
    % 2. 误比特率 (BER)
    tx_bits = sign(real(tx)) > 0;
    rx_bits = sign(real(rx)) > 0;
    num_errors = sum(tx_bits ~= rx_bits);
    ber = num_errors / N;
    
    % 3. 信号功率和噪声功率
    signal_power = mean(abs(tx).^2);
    noise_power = mean(abs(error_vector).^2);
    snr_linear = signal_power / noise_power;
    snr_db = 10 * log10(snr_linear);
    
    % 4. 平均符号能量
    avg_symbol_energy = mean(abs(rx).^2);
    
    % 5. 峰值功率和平均功率比 (PAPR)
    peak_power = max(abs(rx).^2);
    papr = peak_power / mean(abs(rx).^2);
    papr_db = 10 * log10(papr);
    
    % 保存到结构体
    metrics.evm_linear = evm_linear;
    metrics.evm_db = evm_db;
    metrics.evm_percent = evm_percent;
    metrics.ber = ber;
    metrics.num_errors = num_errors;
    metrics.snr_db = snr_db;
    metrics.snr_linear = snr_linear;
    metrics.signal_power = signal_power;
    metrics.noise_power = noise_power;
    metrics.avg_symbol_energy = avg_symbol_energy;
    metrics.papr = papr;
    metrics.papr_db = papr_db;
    metrics.total_symbols = N;
    
    % 显示性能指标
    fprintf('\n========== BPSK 解调性能指标 ==========\n');
    fprintf('总符号数: %d\n', N);
    fprintf('误比特数: %d\n', num_errors);
    fprintf('误比特率 (BER): %.6f (%.4e)\n', ber, ber);
    fprintf('误差向量幅度 (EVM):\n');
    fprintf('  - 线性值: %.6f\n', evm_linear);
    fprintf('  - dB值: %.2f dB\n', evm_db);
    fprintf('  - 百分比: %.2f%%\n', evm_percent);
    fprintf('信噪比 (SNR): %.2f dB\n', snr_db);
    fprintf('平均符号能量: %.4f\n', avg_symbol_energy);
    fprintf('峰值功率/平均功率 (PAPR): %.2f dB\n', papr_db);
    fprintf('========================================\n\n');
    
end

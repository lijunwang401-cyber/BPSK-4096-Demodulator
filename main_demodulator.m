%% BPSK 4096点解调主程序
% 功能: 完整的BPSK解调演示程序
% 包含: 信号生成、载波恢复、符号同步、信道均衡、星座图显示
%
% 作者: BPSK解调项目
% 日期: 2026
% 版本: 1.0

clear all;
close all;
clc;

% ==================== 系统参数设置 ====================
fprintf('\n');
fprintf('╔════════════════════════════════════════════════════╗\n');
fprintf('║   BPSK 4096点解调系统 - 主程序                     ║\n');
fprintf('╚════════════════════════════════════════════════════╝\n');
fprintf('\n');

% 系统参数
fs = 102.4e6;           % 采样率: 102.4 MHz
fc = 140e6;             % 中频: 140 MHz
symbol_rate = 200e3;    % 符号率: 200 kHz
num_symbols = 4096;     % 符号数: 4096
equalizer_type = 'LMS'; % 均衡器类型: LMS/NLMS/RLS

fprintf('系统参数配置:\n');
fprintf('  采样率: %.2f MHz\n', fs/1e6);
fprintf('  中频频率: %.2f MHz\n', fc/1e6);
fprintf('  符号率: %.2f kHz\n', symbol_rate/1e3);
fprintf('  总符号数: %d\n', num_symbols);
fprintf('  均衡器类型: %s\n\n', equalizer_type);

% ==================== 第一步: 生成测试信号 ====================
fprintf('═══════════════════════════════════════════════════\n');
fprintf('第一步: 生成BPSK测试信号\n');
fprintf('═══════════════════════════════════════════════════\n');

[rx_signal, tx_bits, tx_symbols, h_channel] = signal_generator(num_symbols, fs, fc, symbol_rate);

fprintf('✓ 信号生成完成\n');
fprintf('  发送比特数: %d\n', length(tx_bits));
fprintf('  发送符号数: %d\n', length(tx_symbols));
fprintf('  信道冲激响应长度: %d\n', length(h_channel));
fprintf('  接收信号长度: %d 样本\n\n', length(rx_signal));

% ==================== 第二步: 执行完整解调流程 ====================
fprintf('═══════════════════════════════════════════════════\n');
fprintf('第二步: 执行完整的BPSK解调流程\n');
fprintf('═══════════════════════════════════════════════════\n');

[demod_bits, demod_symbols, metrics, debug_data] = bpsk_demodulator(rx_signal, fs, fc, symbol_rate, equalizer_type);

% ==================== 第三步: 性能评估 ====================
fprintf('═══════════════════════════════════════════════════\n');
fprintf('第三步: 性能指标评估\n');
fprintf('═══════════════════════════════════════════════════\n');

% 计算误比特率
num_bits = min(length(tx_bits), length(demod_bits));
bit_errors = sum(tx_bits(1:num_bits) ~= demod_bits(1:num_bits));
ber = bit_errors / num_bits;

fprintf('\n✓ 解调性能指标:\n');
fprintf('  误比特数: %d / %d\n', bit_errors, num_bits);
fprintf('  误比特率 (BER): %.6f\n', ber);
fprintf('  误差向量幅度 (EVM): %.2f%%\n', metrics.evm_percent);
fprintf('  信噪比 (SNR): %.2f dB\n', metrics.snr_db);
fprintf('  均衡器滤波器长度: %d\n\n', metrics.filter_length);

% ==================== 第四步: 绘制结果图表 ====================
fprintf('═══════════════════════════════════════════════════\n');
fprintf('第四步: 绘制结果图表\n');
fprintf('═══════════════════════════════════════════════════\n');

% 4.1 解调过程对比 (四个子图)
fprintf('正在绘制: 解调过程星座图对比...\n');
plot_constellation_comparison(...
    debug_data.rx_raw(1:200), ...
    debug_data.carrier_recovered(1:200), ...
    debug_data.synchronized(1:200), ...
    debug_data.equalized(1:200));
sgtitle('BPSK 解调过程对比 (前200个采样点)', 'FontSize', 14, 'FontWeight', 'bold');

% 4.2 最终解调星座图
fprintf('正在绘制: 最终解调星座图...\n');
figure('Position', [400, 100, 900, 700]);
plot_constellation_advanced(tx_symbols(1:length(demod_symbols)), ...
    demod_symbols, '解调后的星座图 (最终结果)', 2);

% 4.3 载波恢复过程
fprintf('正在绘制: 载波恢复过程...\n');
figure('Position', [100, 400, 1000, 500]);
subplot(1, 2, 1);
plot(debug_data.phase_estimate(1:500));
xlabel('样本索引');
ylabel('相位估计 (rad)');
title('Costas环相位跟踪');
grid on;

subplot(1, 2, 2);
plot(debug_data.phase_error(1:500));
xlabel('样本索引');
ylabel('相位误差');
title('Costas环相位误差');
grid on;

% 4.4 符号同步误差
fprintf('正在绘制: 符号同步误差...\n');
figure('Position', [400, 400, 900, 600]);
plot(debug_data.timing_error(1:500));
xlabel('符号索引');
ylabel('时钟误差');
title('Gardner同步器时钟误差');
grid on;

% 4.5 均衡过程收敛
fprintf('正在绘制: 均衡过程收敛曲线...\n');
figure('Position', [700, 400, 900, 600]);
semilogy(debug_data.error_hist);
xlabel('符号索引');
ylabel('均衡误差 (对数)');
title(sprintf('%s均衡器收敛曲线', equalizer_type));
grid on;

% ==================== 第五步: 详细分析 ====================
fprintf('═══════════════════════════════════════════════════\n');
fprintf('第五步: 详细性能分析\n');
fprintf('═══════════════════════════════════════════════════\n');

% 计算各个阶段的EVM
fprintf('\n各个处理阶段的EVM对比:\n');

% 原始接收信号的EVM
raw_evm = evaluate_evm(tx_symbols(1:200), debug_data.rx_raw(1:200));
fprintf('  原始接收信号 EVM: %.2f%%\n', raw_evm);

% 载波恢复后的EVM
carrier_evm = evaluate_evm(tx_symbols(1:200), debug_data.carrier_recovered(1:200));
fprintf('  载波恢复后 EVM: %.2f%%\n', carrier_evm);

% 符号同步后的EVM
sync_evm = evaluate_evm(tx_symbols(1:100), debug_data.synchronized(1:100));
fprintf('  符号同步后 EVM: %.2f%%\n', sync_evm);

% 均衡后的EVM
eq_evm = evaluate_evm(tx_symbols(1:length(demod_symbols)), demod_symbols);
fprintf('  均衡后 EVM: %.2f%%\n\n', eq_evm);

% ==================== 第六步: 保存结果 ====================
fprintf('═══════════════════════════════════════════════════\n');
fprintf('第六步: 保存结果\n');
fprintf('═══════════════════════════════════════════════════\n');

% 保存工作区变量
save('bpsk_demodulation_results.mat', ...
    'rx_signal', 'tx_bits', 'tx_symbols', 'demod_bits', 'demod_symbols', ...
    'metrics', 'debug_data', 'h_channel');

fprintf('✓ 结果已保存到: bpsk_demodulation_results.mat\n\n');

% ==================== 最终总结 ====================
fprintf('╔════════════════════════════════════════════════════╗\n');
fprintf('║             解调完成 - 最终性能指标总结            ║\n');
fprintf('╠════════════════════════════════════════════════════╣\n');
fprintf('║ 误比特率 (BER):        %-8.6f                 ║\n', ber);
fprintf('║ 误差向量幅度 (EVM):    %-8.2f%%                ║\n', metrics.evm_percent);
fprintf('║ 信噪比 (SNR):          %-8.2f dB              ║\n', metrics.snr_db);
fprintf('║ 总解调符号数:          %-8d                  ║\n', metrics.total_symbols);
fprintf('╚════════════════════════════════════════════════════╝\n\n');

fprintf('程序执行完成! 请查看图表窗口查看详细结果。\n');
fprintf('\n');

% ==================== 辅助函数 ====================

%% 计算EVM的辅助函数
function evm = evaluate_evm(tx_symbols, rx_symbols)
    % 确保长度一致
    N = min(length(tx_symbols), length(rx_symbols));
    tx = tx_symbols(1:N);
    rx = rx_symbols(1:N);
    
    % 计算误差向量
    error_vector = rx - tx;
    
    % 计算EVM (%)
    evm = sqrt(mean(abs(error_vector).^2) / mean(abs(tx).^2)) * 100;
end

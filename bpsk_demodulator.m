%% BPSK 解调核心函数
% 功能: 整合所有解调模块,实现完整的4096点BPSK解调流程
%
% 输入参数:
%   rx_signal - 接收的中频复数信号
%   fs - 采样率 (Hz)
%   fc - 中频频率 (Hz)
%   symbol_rate - 符号率 (Hz)
%   equalizer_type - 均衡器类型 ('LMS', 'NLMS', 'RLS')
%
% 输出:
%   demod_bits - 解调后的比特流
%   demod_symbols - 解调后的符号序列
%   metrics - 性能指标结构体
%   debug_data - 调试数据 (用于绘图)

function [demod_bits, demod_symbols, metrics, debug_data] = bpsk_demodulator(rx_signal, fs, fc, symbol_rate, equalizer_type)
    % 默认参数
    if nargin < 5
        equalizer_type = 'LMS';  % 默认使用LMS均衡器
    end
    
    % ==================== 参数设置 ====================
    samples_per_symbol = fs / symbol_rate;  % 每个符号的采样点数
    
    % Costas环参数
    costas_Kp = 0.01;
    costas_Ki = 0.001;
    
    % Gardner同步器参数
    gardner_Kp = 0.01;
    gardner_Ki = 0.001;
    
    % LMS均衡器参数
    lms_mu = 0.01;
    eq_filter_length = 4096;  % 均衡器长度
    
    fprintf('\n========== BPSK 4096点解调器启动 ==========\n');
    fprintf('采样率: %.2f MHz\n', fs/1e6);
    fprintf('中频频率: %.2f MHz\n', fc/1e6);
    fprintf('符号率: %.2f kHz\n', symbol_rate/1e3);
    fprintf('每符号采样数: %.1f\n', samples_per_symbol);
    fprintf('均衡器类型: %s\n', equalizer_type);
    fprintf('均衡器长度: %d\n', eq_filter_length);
    fprintf('==========================================\n\n');
    
    % ==================== 第一步: Costas环载波恢复 ====================
    fprintf('正在执行Costas环载波恢复...\n');
    [carrier_recovered_signal, phase_error, phase_estimate] = costas_loop(rx_signal, fc, fs, costas_Kp, costas_Ki);
    fprintf('载波恢复完成\n\n');
    
    % 保存调试数据
    debug_data.rx_raw = rx_signal;
    debug_data.carrier_recovered = carrier_recovered_signal;
    debug_data.phase_error = phase_error;
    debug_data.phase_estimate = phase_estimate;
    
    % ==================== 第二步: Gardner符号同步 ====================
    fprintf('正在执行Gardner符号同步...\n');
    [synchronized_symbols, timing_error, sampling_indices] = gardner_synchronizer(carrier_recovered_signal, samples_per_symbol, gardner_Kp, gardner_Ki);
    fprintf('符号同步完成,提取 %d 个符号\n\n', length(synchronized_symbols));
    
    % 保存调试数据
    debug_data.synchronized = synchronized_symbols;
    debug_data.timing_error = timing_error;
    debug_data.sampling_indices = sampling_indices;
    
    % ==================== 第三步: 信道均衡 ====================
    fprintf('正在执行信道均衡 (使用%s算法)...\n', equalizer_type);
    
    switch upper(equalizer_type)
        case 'LMS'
            [equalized_symbols, filter_coeff, error_hist] = lms_equalizer(synchronized_symbols, eq_filter_length, lms_mu);
        case 'NLMS'
            [equalized_symbols, filter_coeff, error_hist] = nlms_equalizer(synchronized_symbols, eq_filter_length, 0.1);
        case 'RLS'
            [equalized_symbols, filter_coeff, error_hist] = rls_equalizer(synchronized_symbols, eq_filter_length, 0.98);
        otherwise
            warning('未知的均衡器类型,使用默认LMS');
            [equalized_symbols, filter_coeff, error_hist] = lms_equalizer(synchronized_symbols, eq_filter_length, lms_mu);
    end
    
    fprintf('信道均衡完成\n\n');
    
    % 保存调试数据
    debug_data.equalized = equalized_symbols;
    debug_data.filter_coeff = filter_coeff;
    debug_data.error_hist = error_hist;
    
    % ==================== 第四步: 符号判决 ====================
    fprintf('正在执行符号判决...\n');
    
    % BPSK符号判决: 根据实部符号
    demod_symbols = sign(real(equalized_symbols)) + 1j * sign(imag(equalized_symbols));
    
    % 比特映射: 1 -> +1, 0 -> -1
    % 反映射: +1 -> 1, -1 -> 0
    demod_bits = (sign(real(demod_symbols)) > 0);
    
    fprintf('符号判决完成,解调比特数: %d\n\n', length(demod_bits));
    
    % 保存调试数据
    debug_data.demod_symbols = demod_symbols;
    debug_data.demod_bits = demod_bits;
    
    % ==================== 第五步: 计算性能指标 ====================
    fprintf('正在计算性能指标...\n\n');
    
    % 计算各种指标
    error_vector = equalized_symbols - demod_symbols;
    evm = sqrt(mean(abs(error_vector).^2)) / sqrt(mean(abs(demod_symbols).^2)) * 100;
    
    % 计算接收功率
    rx_power = mean(abs(equalized_symbols).^2);
    
    % 计算噪声功率
    noise_power = mean(abs(error_vector).^2);
    
    % 计算信噪比
    snr_db = 10 * log10(rx_power / noise_power);
    
    % 存储指标
    metrics.evm_percent = evm;
    metrics.evm_db = 20 * log10(evm / 100);
    metrics.snr_db = snr_db;
    metrics.rx_power = rx_power;
    metrics.noise_power = noise_power;
    metrics.total_symbols = length(equalized_symbols);
    metrics.filter_length = eq_filter_length;
    metrics.equalizer_type = equalizer_type;
    
    % ==================== 显示最终结果 ====================
    fprintf('\n========== 解调完成 - 最终性能指标 ==========\n');
    fprintf('解调符号数: %d\n', metrics.total_symbols);
    fprintf('误差向量幅度 (EVM): %.2f %% (%.2f dB)\n', metrics.evm_percent, metrics.evm_db);
    fprintf('信噪比 (SNR): %.2f dB\n', metrics.snr_db);
    fprintf('接收符号功率: %.4f\n', metrics.rx_power);
    fprintf('噪声功率: %.4f\n', metrics.noise_power);
    fprintf('===========================================\n\n');
    
end

%% 辅助函数: 计算解调性能
function performance = evaluate_demodulation(tx_bits, rx_bits, tx_symbols, rx_symbols)
    
    % 确保长度相同
    N = min(length(tx_bits), length(rx_bits));
    tx_bits = tx_bits(1:N);
    rx_bits = rx_bits(1:N);
    
    % 误比特数和误比特率
    num_errors = sum(tx_bits ~= rx_bits);
    ber = num_errors / N;
    
    % EVM
    tx_sym = 2 * tx_bits - 1;  % 转换为符号
    error_vec = rx_symbols(1:N) - tx_sym;
    evm = sqrt(mean(abs(error_vec).^2)) / sqrt(mean(abs(tx_sym).^2)) * 100;
    
    % 存储结果
    performance.ber = ber;
    performance.num_errors = num_errors;
    performance.evm_percent = evm;
    performance.total_bits = N;
    
end

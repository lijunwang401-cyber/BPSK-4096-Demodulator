%% BPSK 4096点测试信号生成器
% 功能: 生成带有信道衰落的中频BPSK信号
% 参数说明:
%   - 采样率: 102.4 MHz
%   - 中频: 140 MHz
%   - 符号率: 200 kHz
%   - 信号长度: 4096 符号
%
% 输出: 
%   rx_signal - 接收到的复数信号
%   tx_bits - 发送的比特流
%   symbols - 发送的符号
%   h_channel - 信道冲激响应

function [rx_signal, tx_bits, symbols, h_channel] = signal_generator(num_symbols, fs, fc, symbol_rate)
    % 参数设置
    % fs = 102.4e6;          % 采样率 (Hz)
    % fc = 140e6;            % 中频 (Hz)
    % symbol_rate = 200e3;   % 符号率 (Hz)
    % num_symbols = 4096;    % 符号数
    
    % 计算每个符号的采样点数
    samples_per_symbol = fs / symbol_rate;
    
    % 生成随机比特流 (BPSK: 0->-1, 1->+1)
    tx_bits = randi([0, 1], 1, num_symbols);
    symbols = 2 * tx_bits - 1;  % BPSK映射: 0->-1, 1->+1
    
    % 上采样 (符号转采样序列)
    baseband_signal = zeros(1, num_symbols * samples_per_symbol);
    baseband_signal(1:samples_per_symbol:end) = symbols;
    
    % 根升余弦滤波器 (平方根升余弦, RRC)
    rrc_filter = rcosdesign(0.3, 10, samples_per_symbol, 'sqrt');
    baseband_signal = filter(rrc_filter, 1, baseband_signal);
    
    % 调制到中频
    t = (0:length(baseband_signal)-1) / fs;
    carrier = exp(1j * 2 * pi * fc * t);
    modulated_signal = baseband_signal .* carrier;
    
    % 信道模型 (简单的多径衰落)
    % h_channel = [1, 0.3*exp(1j*pi/4), 0.15*exp(1j*pi/3)];  % 3径信道
    h_channel = [1, 0.2*exp(1j*pi/6), 0.1*exp(1j*pi/4)];  % 3径信道
    
    % 信号通过信道
    channel_output = zeros(1, length(modulated_signal) + length(h_channel) - 1);
    for k = 1:length(h_channel)
        channel_output = channel_output + h_channel(k) * [modulated_signal, zeros(1, k-1)];
    end
    channel_output = channel_output(1:length(modulated_signal));
    
    % 添加AWGN噪声 (SNR = 20 dB)
    snr_db = 20;
    signal_power = mean(abs(channel_output).^2);
    noise_power = signal_power / (10^(snr_db/10));
    noise = sqrt(noise_power/2) * (randn(size(channel_output)) + 1j*randn(size(channel_output)));
    
    % 接收信号
    rx_signal = channel_output + noise;
    
    % 返回结果
    % rx_signal: 接收到的中频复数信号
    % tx_bits: 发送的比特流
    % symbols: 发送的BPSK符号
    % h_channel: 真实的信道冲激响应
end

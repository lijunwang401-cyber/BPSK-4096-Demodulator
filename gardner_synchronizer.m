%% Gardner 符号同步器
% 功能: 实现Gardner误差检测器用于符号时钟恢复
% 原理: 基于符号前、中、后三个采样点的误差检测
%
% 输入参数:
%   rx_signal - 接收的复数信号
%   samples_per_symbol - 每个符号的采样点数
%   Kp - 比例增益
%   Ki - 积分增益
%
% 输出:
%   synchronized_signal - 同步后的符号序列
%   timing_error - 时钟误差序列
%   sampling_indices - 最优采样点的索引

function [synchronized_signal, timing_error, sampling_indices] = gardner_synchronizer(rx_signal, samples_per_symbol, Kp, Ki)
    % 默认参数
    if nargin < 3
        Kp = 0.01;  % 比例增益
    end
    if nargin < 4
        Ki = 0.001; % 积分增益
    end
    
    N = length(rx_signal);
    num_symbols = floor(N / samples_per_symbol);
    
    synchronized_signal = zeros(1, num_symbols);
    timing_error = zeros(1, num_symbols);
    sampling_indices = zeros(1, num_symbols);
    
    % 初始化时钟恢复状态
    tau = samples_per_symbol / 2;  % 初始采样偏差 (在符号中间)
    integral_val = 0;               % 积分器状态
    
    for k = 1:num_symbols
        % 计算三个采样点的索引
        % e_k-1: 符号前一个采样点
        % e_k:   符号中间采样点
        % e_k+1: 符号后一个采样点
        
        center_idx = round(k * samples_per_symbol - samples_per_symbol / 2 + tau);
        
        % 确保索引在有效范围内
        if center_idx < 2 || center_idx > N - 1
            if center_idx < 2
                center_idx = 2;
            else
                center_idx = N - 1;
            end
        end
        
        % 获取三个采样点
        early_idx = center_idx - 1;
        late_idx = center_idx + 1;
        
        if early_idx > 0 && late_idx <= N
            early = rx_signal(early_idx);
            center = rx_signal(center_idx);
            late = rx_signal(late_idx);
            
            % Gardner误差检测器
            % e = Re[(y_k - y_k-2) * conj(y_k-1)]
            error = real((late - early) * conj(center));
            
            timing_error(k) = error;
            
            % 环滤波器 (PI控制器)
            integral_val = integral_val + Ki * error;
            tau_correction = Kp * error + integral_val;
            
            % 更新采样点偏差
            tau = tau + tau_correction;
            
            % 限制tau在合理范围内
            tau = mod(tau + samples_per_symbol/2, samples_per_symbol) - samples_per_symbol/2;
            
        else
            error = 0;
            timing_error(k) = error;
        end
        
        % 保存同步后的符号和采样索引
        synchronized_signal(k) = center;
        sampling_indices(k) = center_idx;
    end
    
end

%% Gardner 同步器增强版本 (分数采样)
% 功能: 基于线性插值实现分数采样的Gardner同步器
%
% 输入参数:
%   rx_signal - 接收的复数信号
%   samples_per_symbol - 每个符号的采样点数
%   Kp - 比例增益
%   Ki - 积分增益
%
% 输出:
%   synchronized_signal - 同步后的符号序列
%   timing_error - 时钟误差序列
%   tau_history - 时钟偏差历史

function [synchronized_signal, timing_error, tau_history] = gardner_synchronizer_interpolated(rx_signal, samples_per_symbol, Kp, Ki)
    % 默认参数
    if nargin < 3
        Kp = 0.01;
    end
    if nargin < 4
        Ki = 0.001;
    end
    
    N = length(rx_signal);
    num_symbols = floor(N / samples_per_symbol) - 2;
    
    synchronized_signal = zeros(1, num_symbols);
    timing_error = zeros(1, num_symbols);
    tau_history = zeros(1, num_symbols);
    
    % 初始化
    tau = 0;  % 采样偏差 (相对于符号中间)
    integral_val = 0;
    
    for k = 1:num_symbols
        % 符号中心索引
        sym_center = k * samples_per_symbol + samples_per_symbol / 2;
        
        % 三个采样点的位置 (使用分数延迟)
        early_pos = sym_center - samples_per_symbol / 2 - 1 + tau;
        center_pos = sym_center + tau;
        late_pos = sym_center + samples_per_symbol / 2 + 1 + tau;
        
        % 分数采样 (线性插值)
        early = fractional_sample(rx_signal, early_pos);
        center = fractional_sample(rx_signal, center_pos);
        late = fractional_sample(rx_signal, late_pos);
        
        % Gardner误差
        error = real((late - early) * conj(center));
        timing_error(k) = error;
        
        % 环滤波器
        integral_val = integral_val + Ki * error;
        tau_correction = Kp * error + integral_val;
        
        % 更新采样偏差
        tau = tau + tau_correction;
        
        % 保持tau在合理范围
        if tau > samples_per_symbol / 2
            tau = tau - samples_per_symbol;
            sym_center = sym_center + samples_per_symbol;
        elseif tau < -samples_per_symbol / 2
            tau = tau + samples_per_symbol;
            sym_center = sym_center - samples_per_symbol;
        end
        
        % 重新计算最终中心位置并采样
        center_pos = sym_center + tau;
        synchronized_signal(k) = fractional_sample(rx_signal, center_pos);
        tau_history(k) = tau;
    end
    
end

%% 辅助函数: 分数采样
% 功能: 使用线性插值实现分数延迟采样
function sample = fractional_sample(signal, position)
    % 确保position在有效范围内
    if position < 1
        position = 1;
    elseif position > length(signal)
        position = length(signal);
    end
    
    % 整数部分和小数部分
    idx1 = floor(position);
    idx2 = ceil(position);
    frac = position - idx1;
    
    % 确保索引有效
    idx1 = max(1, min(idx1, length(signal)));
    idx2 = max(1, min(idx2, length(signal)));
    
    % 线性插值
    if idx1 == idx2
        sample = signal(idx1);
    else
        sample = (1 - frac) * signal(idx1) + frac * signal(idx2);
    end
end

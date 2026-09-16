%% Costas 环载波恢复
% 功能: 实现二阶Costas环用于BPSK信号的载波恢复
% 原理: 通过锁相环估计并跟踪载波相位偏差
%
% 输入参数:
%   rx_signal - 接收的中频复数信号
%   fc - 中频频率 (Hz)
%   fs - 采样率 (Hz)
%   Kp - 比例增益
%   Ki - 积分增益
%
% 输出:
%   corrected_signal - 载波恢复后的信号
%   phase_error - 跟踪的相位误差序列
%   phase_estimate - 估计的相位序列

function [corrected_signal, phase_error, phase_estimate] = costas_loop(rx_signal, fc, fs, Kp, Ki)
    % 默认参数
    if nargin < 4
        Kp = 0.01;  % 比例增益
    end
    if nargin < 5
        Ki = 0.001; % 积分增益
    end
    
    N = length(rx_signal);
    corrected_signal = zeros(size(rx_signal));
    phase_error = zeros(1, N);
    phase_estimate = zeros(1, N);
    
    % 初始化Costas环状态
    phase_estimate_val = 0;  % 相位估计
    integral_val = 0;         % 积分器状态
    
    for n = 1:N
        % 1. 下变频: 乘以本地载波的共轭
        local_carrier = exp(1j * phase_estimate_val);
        downconverted = rx_signal(n) * conj(local_carrier);
        corrected_signal(n) = downconverted;
        
        % 2. 分离I和Q分量
        I = real(downconverted);
        Q = imag(downconverted);
        
        % 3. 相位误差检测 (对于BPSK, 使用Q*sign(I))
        % 这是BPSK的经典Costas环判决算法
        phase_err = Q * sign(I);  % 符号判决后的相位误差
        phase_error(n) = phase_err;
        
        % 4. 环滤波器 (比例-积分)
        integral_val = integral_val + Ki * phase_err;
        phase_correction = Kp * phase_err + integral_val;
        
        % 5. 更新相位估计
        phase_estimate_val = phase_estimate_val + phase_correction;
        phase_estimate(n) = phase_estimate_val;
        
        % 保持相位在[-pi, pi]范围内
        phase_estimate_val = mod(phase_estimate_val + pi, 2*pi) - pi;
    end
    
end

%% Costas环增强版本 (带自适应增益)
% 功能: 改进的Costas环实现，具有自适应增益调整
%
% 输入参数:
%   rx_signal - 接收的中频复数信号
%   fc - 中频频率 (Hz)
%   fs - 采样率 (Hz)
%   init_Kp - 初始比例增益
%   init_Ki - 初始积分增益
%
% 输出:
%   corrected_signal - 载波恢复后的信号
%   phase_error - 跟踪的相位误差序列
%   phase_estimate - 估计的相位序列
%   loop_filter_output - 环滤波器输出

function [corrected_signal, phase_error, phase_estimate, loop_filter_output] = costas_loop_adaptive(rx_signal, fc, fs, init_Kp, init_Ki)
    % 默认参数
    if nargin < 4
        init_Kp = 0.01;   % 初始比例增益
    end
    if nargin < 5
        init_Ki = 0.001;  % 初始积分增益
    end
    
    N = length(rx_signal);
    corrected_signal = zeros(size(rx_signal));
    phase_error = zeros(1, N);
    phase_estimate = zeros(1, N);
    loop_filter_output = zeros(1, N);
    
    % 初始化状态
    phase_estimate_val = 0;
    integral_val = 0;
    Kp = init_Kp;
    Ki = init_Ki;
    
    % 自适应参数
    window_size = 100;  % 窗口大小用于计算误差功率
    error_history = [];
    
    for n = 1:N
        % 下变频
        local_carrier = exp(1j * phase_estimate_val);
        downconverted = rx_signal(n) * conj(local_carrier);
        corrected_signal(n) = downconverted;
        
        % 分离I和Q分量
        I = real(downconverted);
        Q = imag(downconverted);
        
        % BPSK相位误差检测
        phase_err = Q * sign(I);
        phase_error(n) = phase_err;
        
        % 记录误差历史用于自适应
        error_history = [error_history, abs(phase_err)];
        if length(error_history) > window_size
            error_history = error_history(end-window_size+1:end);
        end
        
        % 自适应增益调整 (基于误差趋势)
        if n > window_size
            recent_error = mean(error_history(end-window_size/2+1:end));
            old_error = mean(error_history(1:window_size/2));
            
            if recent_error > old_error  % 误差增大，增加增益
                Kp = Kp * 1.01;
                Ki = Ki * 1.01;
            else  % 误差减小，可以减小增益
                Kp = Kp * 0.99;
                Ki = Ki * 0.99;
            end
            
            % 限制增益范围
            Kp = max(init_Kp * 0.5, min(init_Kp * 2, Kp));
            Ki = max(init_Ki * 0.5, min(init_Ki * 2, Ki));
        end
        
        % 环滤波器 (PI控制器)
        integral_val = integral_val + Ki * phase_err;
        phase_correction = Kp * phase_err + integral_val;
        loop_filter_output(n) = phase_correction;
        
        % 更新相位估计
        phase_estimate_val = phase_estimate_val + phase_correction;
        phase_estimate(n) = phase_estimate_val;
        
        % 保持相位在[-pi, pi]范围内
        phase_estimate_val = mod(phase_estimate_val + pi, 2*pi) - pi;
    end
    
end

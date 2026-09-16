%% LMS 信道均衡器
% 功能: 实现最小均方(LMS)算法进行自适应信道均衡
% 原理: 基于误差信号自适应调整均衡滤波器系数
%
% 输入参数:
%   rx_symbols - 接收的符号序列
%   filter_length - 均衡器滤波器长度
%   mu - 步长参数 (学习率)
%   training_symbols - 训练序列(可选,用于有导频的情况)
%
% 输出:
%   equalized_symbols - 均衡后的符号
%   filter_coefficients - 最终的均衡器系数
%   error_history - 误差历史

function [equalized_symbols, filter_coefficients, error_history] = lms_equalizer(rx_symbols, filter_length, mu, training_symbols)
    % 默认参数
    if nargin < 3
        mu = 0.01;  % 步长参数
    end
    if nargin < 4
        training_symbols = [];  % 默认无导频训练
    end
    
    N = length(rx_symbols);
    
    % 初始化均衡器系数 (中心抽头为主)
    filter_coefficients = zeros(filter_length, 1);
    filter_coefficients(ceil(filter_length/2)) = 1;  % 中心抽头初始为1
    
    equalized_symbols = zeros(1, N);
    error_history = zeros(1, N);
    
    % LMS自适应均衡
    for n = filter_length:N
        % 构建输入向量 (时延线)
        x = rx_symbols(n:-1:n-filter_length+1)';
        
        % 均衡器输出
        y = filter_coefficients' * x;
        equalized_symbols(n) = y;
        
        % 误差计算
        if ~isempty(training_symbols) && n <= length(training_symbols)
            % 有导频信号的情况
            desired = training_symbols(n);
        else
            % 无导频信号,使用判决反馈
            desired = sign(real(y)) + 1j * sign(imag(y));
        end
        
        error = desired - y;
        error_history(n) = abs(error);
        
        % LMS系数更新
        filter_coefficients = filter_coefficients + mu * conj(error) * x;
    end
    
    % 填充前面未处理的样本
    for n = 1:filter_length-1
        x = [rx_symbols(n:-1:1), zeros(1, filter_length-n)]';
        equalized_symbols(n) = filter_coefficients' * x;
    end
    
end

%% 归一化LMS (NLMS) 均衡器
% 功能: 改进的LMS算法,具有步长自适应能力
% 优点: 对输入信号功率变化更加稳定
%
% 输入参数:
%   rx_symbols - 接收的符号序列
%   filter_length - 均衡器滤波器长度
%   mu - 步长参数 (0 < mu < 2)
%   epsilon - 小常数,防止除以零
%   training_symbols - 训练序列(可选)
%
% 输出:
%   equalized_symbols - 均衡后的符号
%   filter_coefficients - 最终的均衡器系数
%   error_history - 误差历史
%   convergence_curve - 收敛曲线(误差均方根)

function [equalized_symbols, filter_coefficients, error_history, convergence_curve] = nlms_equalizer(rx_symbols, filter_length, mu, epsilon, training_symbols)
    % 默认参数
    if nargin < 3
        mu = 0.1;  % 步长参数
    end
    if nargin < 4
        epsilon = 1e-6;  % 防止除以零的小常数
    end
    if nargin < 5
        training_symbols = [];
    end
    
    N = length(rx_symbols);
    
    % 初始化均衡器系数
    filter_coefficients = zeros(filter_length, 1);
    filter_coefficients(ceil(filter_length/2)) = 1;
    
    equalized_symbols = zeros(1, N);
    error_history = zeros(1, N);
    convergence_curve = zeros(1, N);
    
    % 窗口大小(用于计算收敛曲线)
    window_size = 100;
    error_window = [];
    
    % NLMS自适应均衡
    for n = filter_length:N
        % 构建输入向量
        x = rx_symbols(n:-1:n-filter_length+1)';
        
        % 均衡器输出
        y = filter_coefficients' * x;
        equalized_symbols(n) = y;
        
        % 误差计算
        if ~isempty(training_symbols) && n <= length(training_symbols)
            desired = training_symbols(n);
        else
            % 判决反馈
            if n > filter_length + 100  % 等待收敛后再使用判决反馈
                desired = sign(real(y)) + 1j * sign(imag(y));
            else
                % 前期使用无导频的盲均衡
                desired = y / abs(y);  % 恢复符号幅度
            end
        end
        
        error = desired - y;
        error_history(n) = abs(error);
        
        % 计算输入功率 (用于规范化)
        input_power = (x' * conj(x)) + epsilon;
        
        % NLMS系数更新 (归一化步长)
        filter_coefficients = filter_coefficients + (mu / input_power) * conj(error) * x;
        
        % 计算收敛曲线
        error_window = [error_window, abs(error)];
        if length(error_window) > window_size
            error_window = error_window(end-window_size+1:end);
        end
        if length(error_window) >= 10
            convergence_curve(n) = sqrt(mean(error_window.^2));
        end
    end
    
    % 填充前面未处理的样本
    for n = 1:filter_length-1
        x = [rx_symbols(n:-1:1), zeros(1, filter_length-n)]';
        equalized_symbols(n) = filter_coefficients' * x;
    end
    
end

%% RLS (递推最小二乘) 均衡器
% 功能: 基于RLS算法的快速收敛信道均衡
% 优点: 收敛速度比LMS快,更适合时变信道
%
% 输入参数:
%   rx_symbols - 接收的符号序列
%   filter_length - 均衡器滤波器长度
%   lambda - 遗忘因子 (0 < lambda <= 1)
%   delta - 初始协方差矩阵的倒数参数
%   training_symbols - 训练序列(可选)
%
% 输出:
%   equalized_symbols - 均衡后的符号
%   filter_coefficients - 最终的均衡器系数
%   error_history - 误差历史

function [equalized_symbols, filter_coefficients, error_history] = rls_equalizer(rx_symbols, filter_length, lambda, delta, training_symbols)
    % 默认参数
    if nargin < 3
        lambda = 0.98;  % 遗忘因子
    end
    if nargin < 4
        delta = 0.1;  % 初始协方差矩阵参数
    end
    if nargin < 5
        training_symbols = [];
    end
    
    N = length(rx_symbols);
    
    % 初始化
    filter_coefficients = zeros(filter_length, 1);
    filter_coefficients(ceil(filter_length/2)) = 1;
    
    % 初始化协方差矩阵的倒数 P = (R^-1)
    P = (1/delta) * eye(filter_length);
    
    equalized_symbols = zeros(1, N);
    error_history = zeros(1, N);
    
    % RLS自适应均衡
    for n = filter_length:N
        % 构建输入向量
        x = rx_symbols(n:-1:n-filter_length+1)';
        
        % 均衡器输出
        y = filter_coefficients' * x;
        equalized_symbols(n) = y;
        
        % 误差计算
        if ~isempty(training_symbols) && n <= length(training_symbols)
            desired = training_symbols(n);
        else
            % 判决反馈
            desired = sign(real(y)) + 1j * sign(imag(y));
        end
        
        error = desired - y;
        error_history(n) = abs(error);
        
        % RLS系数更新
        % 计算Kalman增益
        numerator = P * conj(x);
        denominator = lambda + (x' * P * conj(x));
        k = numerator / denominator;
        
        % 更新协方差矩阵
        P = (P - k * x' * P) / lambda;
        
        % 更新滤波器系数
        filter_coefficients = filter_coefficients + k * conj(error);
    end
    
    % 填充前面未处理的样本
    for n = 1:filter_length-1
        x = [rx_symbols(n:-1:1), zeros(1, filter_length-n)]';
        equalized_symbols(n) = filter_coefficients' * x;
    end
    
end

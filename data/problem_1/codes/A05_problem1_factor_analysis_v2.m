%% A05_problem1_factor_analysis_v2.m
% A题第一问：影响因素分析修正版 v2
% 修正内容：
% 1. 相关性分析仍保留全部变量；
% 2. 标准化多元线性回归去掉完全共线变量，避免 Avg_U/Sum_U、Avg_T/Sum_T 与单场变量重复；
% 3. 峰值识别采用 P95 分位数阈值 + 连续区间合并，避免 50.000 平台点被重复计算；
% 4. 适配你的 A03_clean_data.mat：变量名为 *_clean。

clear; clc; close all;

%% ===================== 0. 读取数据 =====================
mat_file = 'A03_clean_data.mat';
if exist(mat_file, 'file') ~= 2
    error('未找到 A03_clean_data.mat，请把本脚本放到数据文件同一文件夹下运行。');
end

S = load(mat_file);

% 读取你的清洗后列向量
Temp_C       = S.Temp_C_clean(:);
C_in_gNm3    = S.C_in_gNm3_clean(:);
Q_Nm3h       = S.Q_Nm3h_clean(:);

U1_kV        = S.U1_kV_clean(:);
U2_kV        = S.U2_kV_clean(:);
U3_kV        = S.U3_kV_clean(:);
U4_kV        = S.U4_kV_clean(:);

T1_s         = S.T1_s_clean(:);
T2_s         = S.T2_s_clean(:);
T3_s         = S.T3_s_clean(:);
T4_s         = S.T4_s_clean(:);

C_out        = S.C_out_mgNm3_clean(:);
P_total_kW   = S.P_total_kW_clean(:);

% 辅助变量
Avg_U_kV       = S.Avg_U_kV(:);
Sum_U_kV       = S.Sum_U_kV(:);
Avg_T_s        = S.Avg_T_s(:);
Sum_T_s        = S.Sum_T_s(:);
Dust_Load_g_h  = S.Dust_Load_g_h(:);

n = length(C_out);
time_index = (1:n)';

disp('基础数据检查：');
fprintf('样本数 n = %d\n', n);
fprintf('C_out 最小值 = %.4f, 最大值 = %.4f, 平均值 = %.4f, 标准差 = %.4f\n', ...
    min(C_out), max(C_out), mean(C_out), std(C_out));

%% ===================== 1. 全部变量：描述统计与相关性 =====================
X_all = [Temp_C, C_in_gNm3, Q_Nm3h, Dust_Load_g_h, ...
         U1_kV, U2_kV, U3_kV, U4_kV, Avg_U_kV, Sum_U_kV, ...
         T1_s, T2_s, T3_s, T4_s, Avg_T_s, Sum_T_s];

var_all = {'Temp_C', 'C_in_gNm3', 'Q_Nm3h', 'Dust_Load_g_h', ...
           'U1_kV', 'U2_kV', 'U3_kV', 'U4_kV', 'Avg_U_kV', 'Sum_U_kV', ...
           'T1_s', 'T2_s', 'T3_s', 'T4_s', 'Avg_T_s', 'Sum_T_s'};

p_all = size(X_all, 2);
y = C_out;

% 描述性统计
desc = zeros(p_all+1, 4);
all_data = [X_all, y];
all_name = [var_all, {'C_out'}];

for j = 1:(p_all+1)
    temp = all_data(:, j);
    desc(j, 1) = min(temp);
    desc(j, 2) = max(temp);
    desc(j, 3) = mean(temp);
    desc(j, 4) = std(temp);
end

disp('描述性统计结果：');
disp('列含义：最小值 最大值 均值 标准差');
for j = 1:(p_all+1)
    fprintf('%-18s  min=%10.4f  max=%10.4f  mean=%10.4f  std=%10.4f\n', ...
        all_name{j}, desc(j,1), desc(j,2), desc(j,3), desc(j,4));
end

% 相关性分析
corr_y = zeros(p_all, 1);
for j = 1:p_all
    R = corrcoef(X_all(:, j), y);
    corr_y(j) = R(1, 2);
end

[~, idx_corr] = sort(abs(corr_y), 'descend');

disp('各变量与出口浓度 C_out 的相关性排序：');
fprintf('%-4s %-20s %-15s %-15s\n', '序号', '变量', '相关系数', '绝对相关系数');
for k = 1:p_all
    j = idx_corr(k);
    fprintf('%-4d %-20s %-15.6f %-15.6f\n', k, var_all{j}, corr_y(j), abs(corr_y(j)));
end

%% ===================== 2. 标准化多元线性回归：去掉完全共线变量 =====================
% 说明：
% 不能同时把 U1~U4、Avg_U、Sum_U 全放入回归，因为 Avg_U 和 Sum_U 是 U1~U4 的线性组合；
% 不能同时把 T1~T4、Avg_T、Sum_T 全放入回归，因为 Avg_T 和 Sum_T 是 T1~T4 的线性组合；
% 因此回归只保留原始单场变量，不放平均值和总和，避免矩阵病态导致系数爆炸。

X_reg = [Temp_C, C_in_gNm3, Q_Nm3h, Dust_Load_g_h, ...
         U1_kV, U2_kV, U3_kV, U4_kV, ...
         T1_s, T2_s, T3_s, T4_s];

var_reg = {'Temp_C', 'C_in_gNm3', 'Q_Nm3h', 'Dust_Load_g_h', ...
           'U1_kV', 'U2_kV', 'U3_kV', 'U4_kV', ...
           'T1_s', 'T2_s', 'T3_s', 'T4_s'};

p_reg = size(X_reg, 2);

% Z-score 标准化
X_mean = mean(X_reg);
X_std = std(X_reg);
y_mean = mean(y);
y_std = std(y);

Xz = zeros(size(X_reg));
for j = 1:p_reg
    if X_std(j) == 0
        Xz(:, j) = 0;
    else
        Xz(:, j) = (X_reg(:, j) - X_mean(j)) / X_std(j);
    end
end

yz = (y - y_mean) / y_std;
Xmat = [ones(n, 1), Xz];

% 普通最小二乘
beta = Xmat \ yz;
y_pred_z = Xmat * beta;
y_pred = y_pred_z * y_std + y_mean;

residual = y - y_pred;
SSE = sum(residual .^ 2);
SST = sum((y - mean(y)) .^ 2);
R2 = 1 - SSE / SST;
RMSE = sqrt(mean(residual .^ 2));
MAE = mean(abs(residual));

std_beta = beta(2:end);
[~, idx_beta] = sort(abs(std_beta), 'descend');

disp('修正后的标准化多元线性回归结果：');
fprintf('R2 = %.8f, RMSE = %.8f, MAE = %.8f\n', R2, RMSE, MAE);

disp('修正后的标准化回归系数重要性排序：');
fprintf('%-4s %-20s %-15s %-15s\n', '序号', '变量', '标准化系数', '绝对值');
for k = 1:p_reg
    j = idx_beta(k);
    fprintf('%-4d %-20s %-15.8f %-15.8f\n', k, var_reg{j}, std_beta(j), abs(std_beta(j)));
end

%% ===================== 3. 分组均值分析 =====================
group_mean = zeros(p_all, 3);
group_count = zeros(p_all, 3);

for j = 1:p_all
    xj = X_all(:, j);

    % 用排序法计算 1/3 和 2/3 分位点，避免 prctile 不兼容
    x_sort = sort(xj);
    idx33 = ceil(0.333333 * length(x_sort));
    idx66 = ceil(0.666667 * length(x_sort));
    q1 = x_sort(idx33);
    q2 = x_sort(idx66);

    idx_low = find(xj <= q1);
    idx_mid = find(xj > q1 & xj <= q2);
    idx_high = find(xj > q2);

    group_count(j, 1) = length(idx_low);
    group_count(j, 2) = length(idx_mid);
    group_count(j, 3) = length(idx_high);

    group_mean(j, 1) = mean(y(idx_low));
    group_mean(j, 2) = mean(y(idx_mid));
    group_mean(j, 3) = mean(y(idx_high));
end

disp('分组均值分析：每个变量按低/中/高三组比较出口浓度均值');
fprintf('%-20s %-12s %-12s %-12s\n', '变量', '低水平', '中水平', '高水平');
for j = 1:p_all
    fprintf('%-20s %-12.6f %-12.6f %-12.6f\n', ...
        var_all{j}, group_mean(j,1), group_mean(j,2), group_mean(j,3));
end

%% ===================== 4. 非线性关系简单检验 =====================
R2_linear = zeros(p_all, 1);
R2_quad = zeros(p_all, 1);
R2_improve = zeros(p_all, 1);

for j = 1:p_all
    xj = X_all(:, j);
    xjz = (xj - mean(xj)) / std(xj);

    A1 = [ones(n,1), xjz];
    b1 = A1 \ y;
    pred1 = A1 * b1;
    SSE1 = sum((y - pred1).^2);
    R2_linear(j) = 1 - SSE1 / SST;

    A2 = [ones(n,1), xjz, xjz.^2];
    b2 = A2 \ y;
    pred2 = A2 * b2;
    SSE2 = sum((y - pred2).^2);
    R2_quad(j) = 1 - SSE2 / SST;

    R2_improve(j) = R2_quad(j) - R2_linear(j);
end

[~, idx_improve] = sort(R2_improve, 'descend');

disp('非线性简单检验：加入平方项后 R2 提升排序');
fprintf('%-4s %-20s %-12s %-12s %-12s\n', '序号', '变量', '线性R2', '二次R2', '提升量');
for k = 1:p_all
    j = idx_improve(k);
    fprintf('%-4d %-20s %-12.8f %-12.8f %-12.8f\n', ...
        k, var_all{j}, R2_linear(j), R2_quad(j), R2_improve(j));
end

%% ===================== 5. 滞后效应分析 =====================
max_lag = 60;
lag_corr = zeros(p_all, max_lag+1);
best_lag = zeros(p_all, 1);
best_lag_corr = zeros(p_all, 1);

for j = 1:p_all
    for lag = 0:max_lag
        if lag == 0
            x_lag = X_all(:, j);
            y_now = y;
        else
            x_lag = X_all(1:n-lag, j);
            y_now = y(1+lag:n);
        end
        R = corrcoef(x_lag, y_now);
        lag_corr(j, lag+1) = R(1, 2);
    end

    [~, temp_idx] = max(abs(lag_corr(j, :)));
    best_lag(j) = temp_idx - 1;
    best_lag_corr(j) = lag_corr(j, temp_idx);
end

[~, idx_lag] = sort(abs(best_lag_corr), 'descend');

disp('滞后效应分析：0~60分钟内最大绝对相关性排序');
fprintf('%-4s %-20s %-12s %-15s\n', '序号', '变量', '最佳滞后/min', '对应相关系数');
for k = 1:p_all
    j = idx_lag(k);
    fprintf('%-4d %-20s %-12d %-15.8f\n', ...
        k, var_all{j}, best_lag(j), best_lag_corr(j));
end

%% ===================== 6. 峰值事件识别：P95 + 连续区间合并 =====================
% 原因：
% 本数据中 C_out 大量等于 50.0000，P95 也等于 50.0000。
% 如果把所有 y>=P95 的点都当峰值，会把长期贴近上限的平台重复计数。
% 因此这里把连续满足条件的点合并为一个“峰值事件”。

y_sort = sort(y);
idx95 = ceil(0.95 * length(y_sort));
p95_y = y_sort(idx95);

peak_threshold = p95_y;
is_peak_candidate = y >= peak_threshold;

peak_idx = [];
peak_start = [];
peak_end = [];

in_seg = 0;
seg_start = 1;

for ii = 1:n
    if is_peak_candidate(ii) == 1 && in_seg == 0
        in_seg = 1;
        seg_start = ii;
    end

    if in_seg == 1
        if ii == n || is_peak_candidate(ii+1) == 0
            seg_end = ii;

            % 在该连续区间内取最大值所在点；若多个最大值，取中间那个
            seg_y = y(seg_start:seg_end);
            max_y = max(seg_y);
            locs = find(seg_y == max_y);
            loc_mid = locs(ceil(length(locs)/2));
            idx_peak = seg_start + loc_mid - 1;

            peak_idx = [peak_idx; idx_peak];
            peak_start = [peak_start; seg_start];
            peak_end = [peak_end; seg_end];

            in_seg = 0;
        end
    end
end

num_peak_event = length(peak_idx);
peak_event_rate = num_peak_event / n;

disp('峰值事件识别结果：');
fprintf('峰值阈值 P95 = %.6f\n', peak_threshold);
fprintf('峰值事件个数 = %d，占总样本比例 = %.4f%%\n', num_peak_event, peak_event_rate*100);
fprintf('说明：这里统计的是连续高值区间合并后的峰值事件，不是高值点个数。\n');

%% ===================== 7. 峰值前后振打周期窗口分析 =====================
win = 30;
T_mat = [T1_s, T2_s, T3_s, T4_s, Avg_T_s];
T_name = {'T1_s', 'T2_s', 'T3_s', 'T4_s', 'Avg_T_s'};

valid_peak_idx = [];
before_T = [];
after_T = [];
delta_T = [];

for k = 1:num_peak_event
    idx0 = peak_idx(k);

    if idx0-win >= 1 && idx0+win <= n
        valid_peak_idx = [valid_peak_idx; idx0];

        temp_before = mean(T_mat(idx0-win:idx0-1, :), 1);
        temp_after = mean(T_mat(idx0+1:idx0+win, :), 1);
        temp_delta = temp_after - temp_before;

        before_T = [before_T; temp_before];
        after_T = [after_T; temp_after];
        delta_T = [delta_T; temp_delta];
    end
end

num_valid_peak = length(valid_peak_idx);

if num_valid_peak > 0
    avg_before_T = mean(before_T, 1);
    avg_after_T = mean(after_T, 1);
    avg_delta_T = mean(delta_T, 1);

    disp('峰值事件前后振打周期窗口分析结果：');
    fprintf('%-12s %-15s %-15s %-15s\n', '变量', '峰前均值', '峰后均值', '后-前变化');
    for j = 1:5
        fprintf('%-12s %-15.6f %-15.6f %-15.6f\n', ...
            T_name{j}, avg_before_T(j), avg_after_T(j), avg_delta_T(j));
    end
else
    disp('有效峰值事件不足，无法进行峰值前后窗口分析。');
    avg_before_T = zeros(1,5);
    avg_after_T = zeros(1,5);
    avg_delta_T = zeros(1,5);
end

%% ===================== 8. 绘图 =====================

% 图1：出口浓度时序图及峰值阈值
figure;
plot(time_index, y, 'LineWidth', 1);
hold on;
plot(time_index, peak_threshold * ones(n,1), '--', 'LineWidth', 1);
xlabel('时间序号/min');
ylabel('出口粉尘浓度/(mg/Nm^3)');
title('出口粉尘浓度时序图及P95峰值阈值');
legend('出口浓度', 'P95峰值阈值');
grid on;

% 图2：相关性柱状图
figure;
bar(corr_y);
set(gca, 'XTick', 1:p_all);
set(gca, 'XTickLabel', var_all);
% xtickangle(45);
ylabel('相关系数');
title('各影响因素与出口粉尘浓度的相关系数');
grid on;

% 图3：修正后的标准化回归系数柱状图
figure;
bar(std_beta);
set(gca, 'XTick', 1:p_reg);
set(gca, 'XTickLabel', var_reg);
% xtickangle(45);
ylabel('标准化回归系数');
title('去除共线变量后的标准化多元线性回归系数');
grid on;

% 图4：实际值与预测值对比
figure;
plot(time_index, y, 'LineWidth', 1);
hold on;
plot(time_index, y_pred, '--', 'LineWidth', 1);
xlabel('时间序号/min');
ylabel('出口粉尘浓度/(mg/Nm^3)');
title('出口粉尘浓度实际值与修正回归预测值对比');
legend('实际值', '预测值');
grid on;

% 图5：峰值事件识别图
figure;
plot(time_index, y, 'LineWidth', 1);
hold on;
scatter(peak_idx, y(peak_idx), 20, 'filled');
xlabel('时间序号/min');
ylabel('出口粉尘浓度/(mg/Nm^3)');
title('出口粉尘浓度峰值事件识别');
legend('出口浓度', '峰值事件代表点');
grid on;

% 图6：峰值事件前后振打周期均值对比
figure;
bar([avg_before_T(:), avg_after_T(:)]);
set(gca, 'XTick', 1:5);
set(gca, 'XTickLabel', T_name);
ylabel('振打周期/s');
title('峰值事件前后窗口内振打周期均值对比');
legend('峰值前', '峰值后');
grid on;

% 图7：滞后相关性示例图
figure;
plot(0:max_lag, lag_corr(9, :), 'LineWidth', 1); hold on;
plot(0:max_lag, lag_corr(15, :), 'LineWidth', 1);
plot(0:max_lag, lag_corr(4, :), 'LineWidth', 1);
xlabel('滞后时间/min');
ylabel('相关系数');
title('典型变量滞后相关性分析');
legend('平均电压', '平均振打周期', '入口粉尘负荷');
grid on;

%% ===================== 9. 保存结果 =====================
save('A05_problem1_factor_analysis_v2_results.mat', ...
    'desc', 'corr_y', 'idx_corr', ...
    'beta', 'std_beta', 'R2', 'RMSE', 'MAE', ...
    'group_mean', 'group_count', ...
    'R2_linear', 'R2_quad', 'R2_improve', ...
    'lag_corr', 'best_lag', 'best_lag_corr', ...
    'peak_threshold', 'peak_idx', 'peak_start', 'peak_end', 'valid_peak_idx', ...
    'avg_before_T', 'avg_after_T', 'avg_delta_T', ...
    'y_pred', 'var_all', 'var_reg');

fid = fopen('A05_v2_correlation_result.csv', 'w');
fprintf(fid, 'rank,variable,corr,abs_corr\n');
for k = 1:p_all
    j = idx_corr(k);
    fprintf(fid, '%d,%s,%.8f,%.8f\n', k, var_all{j}, corr_y(j), abs(corr_y(j)));
end
fclose(fid);

fid = fopen('A05_v2_regression_coef_result.csv', 'w');
fprintf(fid, 'rank,variable,std_beta,abs_std_beta\n');
for k = 1:p_reg
    j = idx_beta(k);
    fprintf(fid, '%d,%s,%.8f,%.8f\n', k, var_reg{j}, std_beta(j), abs(std_beta(j)));
end
fclose(fid);

fid = fopen('A05_v2_model_metrics.csv', 'w');
fprintf(fid, 'R2,RMSE,MAE\n');
fprintf(fid, '%.8f,%.8f,%.8f\n', R2, RMSE, MAE);
fclose(fid);

fid = fopen('A05_v2_peak_window_T_result.csv', 'w');
fprintf(fid, 'variable,before_peak_mean,after_peak_mean,after_minus_before\n');
for j = 1:5
    fprintf(fid, '%s,%.8f,%.8f,%.8f\n', T_name{j}, avg_before_T(j), avg_after_T(j), avg_delta_T(j));
end
fclose(fid);

fid = fopen('A05_v2_peak_event_result.csv', 'w');
fprintf(fid, 'event_id,peak_index,start_index,end_index,peak_value\n');
for k = 1:num_peak_event
    fprintf(fid, '%d,%d,%d,%d,%.8f\n', k, peak_idx(k), peak_start(k), peak_end(k), y(peak_idx(k)));
end
fclose(fid);

disp('A05 v2 修正版分析完成！');

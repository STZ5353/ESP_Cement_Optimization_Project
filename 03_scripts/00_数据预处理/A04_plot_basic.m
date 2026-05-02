clc;
clear;
close all;

%% =====================================================
% A题第四步：基础图表绘制
% 目标：
% 1. 出口粉尘浓度随时间变化图
% 2. 总电耗随时间变化图
% 3. 入口浓度随时间变化图
% 4. 温度随时间变化图
% 5. 各电场电压变化图
% 6. 各振打周期变化图
% 7. 出口浓度与电耗散点图
%
% 说明：
% 本代码优先读取 A03_clean_data.mat
% 该文件由 A03_preprocess_data.m 生成
%% =====================================================

%% 1. 读取清洗后的 MAT 数据
matFile = 'A03_clean_data.mat';

if exist(matFile, 'file') == 2
    load(matFile);
    fprintf('成功读取文件：%s\n', matFile);
else
    error('未找到 A03_clean_data.mat，请确认它和本脚本在同一个文件夹。');
end

%% 2. 检查关键变量是否存在
% 如果这些变量不存在，说明 A03_preprocess_data.m 可能没有成功运行
if exist('C_out_mgNm3_clean', 'var') ~= 1
    error('缺少变量 C_out_mgNm3_clean，请先运行 A03_preprocess_data.m。');
end

if exist('P_total_kW_clean', 'var') ~= 1
    error('缺少变量 P_total_kW_clean，请先运行 A03_preprocess_data.m。');
end

%% 3. 构造横坐标
% 为了兼容北太天元，这里不用复杂时间格式
% 直接用样本编号作为横坐标
nRows = length(C_out_mgNm3_clean);
t = 1:nRows;

fprintf('数据长度：%d 个采样点。\n', nRows);
fprintf('横坐标使用样本编号，1个样本约代表1分钟。\n');

%% 4. 创建图片保存文件夹
% 如果当前文件夹下没有 figures 文件夹，就新建一个
figDir = 'figures';

if exist(figDir, 'dir') ~= 7
    mkdir(figDir);
end

%% =====================================================
% 图1：出口粉尘浓度随时间变化图
%% =====================================================

figure;
plot(t, C_out_mgNm3_clean, 'LineWidth', 1);
xlabel('样本编号（分钟）');
ylabel('出口粉尘浓度 C_{out} / (mg/Nm^3)');
title('出口粉尘浓度随时间变化图');
grid on;

%saveas(gcf, 'figures/Fig01_Cout_time.png');

fprintf('已生成图1：出口粉尘浓度随时间变化图。\n');

%% =====================================================
% 图1补充：出口粉尘浓度移动平均平滑图
% 目的：让论文图更清晰
%% =====================================================

windowSize = 60;   % 60分钟移动平均，约等于1小时

Cout_smooth = zeros(nRows, 1);

for i = 1:nRows
    
    leftIdx = i - windowSize + 1;
    
    if leftIdx < 1
        leftIdx = 1;
    end
    
    Cout_smooth(i) = mean(C_out_mgNm3_clean(leftIdx:i));
    
end

figure;
plot(t, C_out_mgNm3_clean, 'LineWidth', 0.5);
hold on;
plot(t, Cout_smooth, 'LineWidth', 2);
hold off;

xlabel('样本编号（分钟）');
ylabel('出口粉尘浓度 C_{out} / (mg/Nm^3)');
title('出口粉尘浓度原始曲线与60分钟移动平均曲线');
legend('原始数据', '60分钟移动平均');
grid on;

fprintf('已生成图1补充：出口浓度移动平均平滑图。\n');

%% =====================================================
% 图2：总电耗随时间变化图
%% =====================================================

figure;
plot(t, P_total_kW_clean, 'LineWidth', 1);
xlabel('样本编号（分钟）');
ylabel('总电耗 P_{total} / kW');
title('总电耗随时间变化图');
grid on;

%saveas(gcf, 'figures/Fig02_Power_time.png');

fprintf('已生成图2：总电耗随时间变化图。\n');

%% =====================================================
% 图3：入口粉尘浓度随时间变化图
%% =====================================================

figure;
plot(t, C_in_gNm3_clean, 'LineWidth', 1);
xlabel('样本编号（分钟）');
ylabel('入口粉尘浓度 C_{in} / (g/Nm^3)');
title('入口粉尘浓度随时间变化图');
grid on;

%saveas(gcf, 'figures/Fig03_Cin_time.png');

fprintf('已生成图3：入口粉尘浓度随时间变化图。\n');

%% =====================================================
% 图4：入口温度随时间变化图
%% =====================================================

figure;
plot(t, Temp_C_clean, 'LineWidth', 1);
xlabel('样本编号（分钟）');
ylabel('入口温度 Temp / ℃');
title('入口温度随时间变化图');
grid on;


%saveas(gcf, 'figures/Fig04_Temp_time.png');

fprintf('已生成图4：入口温度随时间变化图。\n');

%% =====================================================
% 图5：四个电场电压变化图
%% =====================================================

figure;
plot(t, U1_kV_clean, 'LineWidth', 1);
hold on;
plot(t, U2_kV_clean, 'LineWidth', 1);
plot(t, U3_kV_clean, 'LineWidth', 1);
plot(t, U4_kV_clean, 'LineWidth', 1);
hold off;

xlabel('样本编号（分钟）');
ylabel('电场电压 / kV');
title('四个电场电压随时间变化图');
legend('U1\_kV', 'U2\_kV', 'U3\_kV', 'U4\_kV');
grid on;

%saveas(gcf, 'figures/Fig05_Voltage_time.png');

fprintf('已生成图5：四个电场电压变化图。\n');

%% =====================================================
% 图6：四个振打周期变化图
%% =====================================================

figure;
plot(t, T1_s_clean, 'LineWidth', 1);
hold on;
plot(t, T2_s_clean, 'LineWidth', 1);
plot(t, T3_s_clean, 'LineWidth', 1);
plot(t, T4_s_clean, 'LineWidth', 1);
hold off;

xlabel('样本编号（分钟）');
ylabel('振打周期 / s');
title('四个振打周期随时间变化图');
legend('T1\_s', 'T2\_s', 'T3\_s', 'T4\_s');
grid on;

%saveas(gcf, 'figures/Fig06_Rapping_time.png');

fprintf('已生成图6：四个振打周期变化图。\n');

%% =====================================================
% 图7：出口粉尘浓度与总电耗散点图
%% =====================================================

figure;
scatter(P_total_kW_clean, C_out_mgNm3_clean, 10, 'filled');
xlabel('总电耗 P_{total} / kW');
ylabel('出口粉尘浓度 C_{out} / (mg/Nm^3)');
title('出口粉尘浓度与总电耗散点图');
grid on;

%saveas(gcf, 'figures/Fig07_Cout_Power_scatter.png');

fprintf('已生成图7：出口浓度与电耗散点图。\n');

%% =====================================================
% 额外图8：平均电压与出口粉尘浓度散点图
% 这个图后续问题1影响因素分析很有用
%% =====================================================

figure;
scatter(Avg_U_kV, C_out_mgNm3_clean, 10, 'filled');
xlabel('平均电压 Avg\_U / kV');
ylabel('出口粉尘浓度 C_{out} / (mg/Nm^3)');
title('平均电压与出口粉尘浓度散点图');
grid on;

%saveas(gcf, 'figures/Fig08_Cout_AvgU_scatter.png');

fprintf('已生成图8：平均电压与出口浓度散点图。\n');

%% =====================================================
% 额外图9：入口粉尘负荷与出口粉尘浓度散点图
% 这个图后续问题1也很有用
%% =====================================================

figure;
scatter(Dust_Load_g_h, C_out_mgNm3_clean, 10, 'filled');
xlabel('入口粉尘负荷 Dust\_Load / (g/h)');
ylabel('出口粉尘浓度 C_{out} / (mg/Nm^3)');
title('入口粉尘负荷与出口粉尘浓度散点图');
grid on;

%saveas(gcf, 'figures/Fig09_Cout_DustLoad_scatter.png');

fprintf('已生成图9：入口粉尘负荷与出口浓度散点图。\n');

%% =====================================================
% 基础相关性计算
%% =====================================================

fprintf('\n================ 基础相关性检查 ================\n');

% 出口浓度与电耗相关系数
R1 = corrcoef(C_out_mgNm3_clean, P_total_kW_clean);
corr_Cout_Power = R1(1, 2);

% 出口浓度与平均电压相关系数
R2 = corrcoef(C_out_mgNm3_clean, Avg_U_kV);
corr_Cout_AvgU = R2(1, 2);

% 出口浓度与入口粉尘负荷相关系数
R3 = corrcoef(C_out_mgNm3_clean, Dust_Load_g_h);
corr_Cout_DustLoad = R3(1, 2);

% 电耗与平均电压相关系数
R4 = corrcoef(P_total_kW_clean, Avg_U_kV);
corr_Power_AvgU = R4(1, 2);

fprintf('出口浓度 与 总电耗 的相关系数：%.4f\n', corr_Cout_Power);
fprintf('出口浓度 与 平均电压 的相关系数：%.4f\n', corr_Cout_AvgU);
fprintf('出口浓度 与 入口粉尘负荷 的相关系数：%.4f\n', corr_Cout_DustLoad);
fprintf('总电耗 与 平均电压 的相关系数：%.4f\n', corr_Power_AvgU);

%% 保存相关性结果
save('A04_basic_plot_result.mat', ...
    'corr_Cout_Power', ...
    'corr_Cout_AvgU', ...
    'corr_Cout_DustLoad', ...
    'corr_Power_AvgU');

fprintf('\n相关性结果已保存为：A04_basic_plot_result.mat\n');

fprintf('\n================ 第四步：基础图表绘制完成 ================\n');
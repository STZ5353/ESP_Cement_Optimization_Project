clc;
clear;
close all;

%% ==============================
% A题数据读取基础版
% 适合北太天元 / MATLAB 风格
% 不使用 data.Properties.VariableNames
% 不使用复杂工具箱
%% ==============================

%% 1. 设置文件名
fileName = 'Cement_ESP_Data.csv';

%% 2. 打开CSV文件
fid = fopen(fileName, 'r');

if fid == -1
    error('文件打开失败，请检查 Cement_ESP_Data.csv 是否和代码在同一个文件夹。');
end

%% 3. 读取第一行表头
headerLine = fgetl(fid);

fprintf('================ 表头信息 ================\n');
disp(headerLine);

%% 4. 手动设置变量名
% 因为北太天元可能不支持 data.Properties.VariableNames
varNames = { ...
    'Timestamp', ...
    'Temp_C', ...
    'C_in_gNm3', ...
    'Q_Nm3h', ...
    'U1_kV', 'U2_kV', 'U3_kV', 'U4_kV', ...
    'T1_s', 'T2_s', 'T3_s', 'T4_s', ...
    'C_out_mgNm3', ...
    'P_total_kW'};

%% 5. 逐行读取数据
% timeStr 用来保存时间戳
% X 用来保存后面的数值数据

timeStr = {};
X = [];

row = 0;

while ~feof(fid)
    
    % 读取一行
    line = fgetl(fid);
    
    % 如果遇到空行，跳过
    if isempty(line)
        continue;
    end
    
    % 按逗号分割
    parts = strsplit(line, ',');
    
    % 正常情况下应该有14列：1列时间戳 + 13列数值
    if length(parts) < 14
        fprintf('警告：第 %d 行列数不足，已跳过。\n', row + 2);
        continue;
    end
    
    row = row + 1;
    
    % 第一列是时间戳
    timeStr{row, 1} = strrep(parts{1}, '"', '');
    
    % 第2列到第14列是数值
    for j = 2:14
        X(row, j-1) = str2double(parts{j});
    end
end

%% 6. 关闭文件
fclose(fid);

%% 7. 显示数据行数、列数
[nRows, nNumCols] = size(X);
nCols = nNumCols + 1;

fprintf('\n================ 数据基本信息 ================\n');
fprintf('数据行数：%d 行\n', nRows);
fprintf('数据列数：%d 列\n', nCols);

%% 8. 显示变量名
fprintf('\n================ 变量名列表 ================\n');

for i = 1:length(varNames)
    fprintf('第 %d 列变量名：%s\n', i, varNames{i});
end

%% 9. 显示前几行数据
fprintf('\n================ 前5行数据 ================\n');

showRows = min(5, nRows);

fprintf('时间戳\t\t\tTemp_C\tC_in\tQ\tU1\tU2\tU3\tU4\tT1\tT2\tT3\tT4\tC_out\tP_total\n');

for i = 1:showRows
    
    % 先输出时间戳
    fprintf('%s\t', timeStr{i});
    
    % 再逐个输出这一行的数值
    for j = 1:nNumCols
        fprintf('%.4f\t', X(i, j));
    end
    
    % 每一行输出完后换行
    fprintf('\n');
    
end

%% 10. 检查每列数据类型
fprintf('\n================ 每列数据类型 ================\n');

fprintf('Timestamp 的数据类型是：字符串 / cell\n');

for i = 2:length(varNames)
    fprintf('%s 的数据类型是：double 数值型\n', varNames{i});
end

%% 11. 把数值列单独取出来，方便后续分析
Temp_C        = X(:, 1);
C_in_gNm3     = X(:, 2);
Q_Nm3h        = X(:, 3);

U1_kV         = X(:, 4);
U2_kV         = X(:, 5);
U3_kV         = X(:, 6);
U4_kV         = X(:, 7);

T1_s          = X(:, 8);
T2_s          = X(:, 9);
T3_s          = X(:, 10);
T4_s          = X(:, 11);

C_out_mgNm3   = X(:, 12);
P_total_kW    = X(:, 13);

fprintf('\n数值变量提取完成。\n');

%% 12. 时间戳连续性检查
fprintf('\n================ 时间戳检查 ================\n');

timeNum = zeros(nRows, 1);
timeOK = 1;

for i = 1:nRows
    
    thisTime = timeStr{i};
    
    % 去掉可能存在的双引号
    thisTime = strrep(thisTime, '"', '');
    
    try
        % 常见格式1：2024-01-01 00:00:00
        timeNum(i) = datenum(thisTime, 'yyyy-mm-dd HH:MM:SS');
    catch
        try
            % 常见格式2：2024/01/01 00:00:00
            timeNum(i) = datenum(thisTime, 'yyyy/mm/dd HH:MM:SS');
        catch
            try
                % 常见格式3：2024-01-01 00:00
                timeNum(i) = datenum(thisTime, 'yyyy-mm-dd HH:MM');
            catch
                fprintf('第 %d 行时间戳无法识别：%s\n', i, thisTime);
                timeOK = 0;
                break;
            end
        end
    end
end

%% 13. 如果时间戳识别成功，则计算采样间隔
if timeOK == 1
    
    % datenum 单位是“天”
    % 乘以 24*60 转换成分钟
    dt_min = diff(timeNum) * 24 * 60;
    
    fprintf('时间戳成功转换。\n');
    
    fprintf('\n================ 采样间隔统计 ================\n');
    fprintf('最小采样间隔：%.4f 分钟\n', min(dt_min));
    fprintf('最大采样间隔：%.4f 分钟\n', max(dt_min));
    fprintf('平均采样间隔：%.4f 分钟\n', mean(dt_min));
    fprintf('中位数采样间隔：%.4f 分钟\n', median(dt_min));
    
    normal_dt = median(dt_min);
    tol = 1e-3;
    
    badIndex = find(abs(dt_min - normal_dt) > tol);
    
    if isempty(badIndex)
        fprintf('\n时间戳检查结果：时间戳基本连续。\n');
    else
        fprintf('\n时间戳检查结果：发现 %d 处时间间隔异常。\n', length(badIndex));
        fprintf('前10处异常如下：\n');
        
        showBad = min(10, length(badIndex));
        
        for k = 1:showBad
            idx = badIndex(k);
            fprintf('第 %d 行 到 第 %d 行，间隔 = %.4f 分钟\n', ...
                idx, idx+1, dt_min(idx));
        end
    end
    
    %% 14. 判断是否为分钟级采样
    if normal_dt >= 0.5 && normal_dt <= 60
        fprintf('\n采样间隔判断：该数据属于分钟级采样数据。\n');
        fprintf('主要采样间隔约为：%.4f 分钟。\n', normal_dt);
    else
        fprintf('\n采样间隔判断：该数据可能不是分钟级采样数据。\n');
        fprintf('主要采样间隔约为：%.4f 分钟。\n', normal_dt);
    end
    
else
    fprintf('\n时间戳识别失败，暂时跳过时间连续性检查。\n');
    fprintf('但数值数据已经成功读取，可以继续做缺失值和异常值检查。\n');
end

fprintf('\n================ 数据读取完成 ================\n');

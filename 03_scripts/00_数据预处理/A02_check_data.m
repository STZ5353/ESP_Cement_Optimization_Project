clc;
clear;
close all;

%% =====================================================
% A题第二步：数据检查
% 目标：
% 1. 重新读取 Cement_ESP_Data.csv
% 2. 不跳过缺失行，缺失位置用 NaN 保留
% 3. 检查每列缺失值
% 4. 检查统计异常值
% 5. 检查出口粉尘浓度峰值
% 6. 检查电压、振打周期、电耗是否存在不合理值
% 7. 保存检查结果，方便后续预处理
%% =====================================================

%% 1. 设置文件名
fileName = 'Cement_ESP_Data.csv';

%% 2. 打开文件
fid = fopen(fileName, 'r');

if fid == -1
    error('文件打开失败，请检查 Cement_ESP_Data.csv 是否和代码在同一个文件夹。');
end

%% 3. 读取表头
headerLine = fgetl(fid);

fprintf('================ 表头信息 ================\n');
disp(headerLine);

%% 4. 手动设置变量名
varNames = { ...
    'Timestamp', ...
    'Temp_C', ...
    'C_in_gNm3', ...
    'Q_Nm3h', ...
    'U1_kV', 'U2_kV', 'U3_kV', 'U4_kV', ...
    'T1_s', 'T2_s', 'T3_s', 'T4_s', ...
    'C_out_mgNm3', ...
    'P_total_kW'};

nTotalCols = 14;       % 总列数：1列时间戳 + 13列数值
nNumCols = 13;         % 数值列数量

%% 5. 逐行读取数据
% timeStr 保存时间戳
% X 保存13列数值数据
% 如果某个数值缺失，就保留为 NaN

timeStr = {};
X = [];

row = 0;

while ~feof(fid)
    
    line = fgetl(fid);
    
    % 如果读到文件末尾，退出
    if ~ischar(line)
        break;
    end
    
    row = row + 1;
    
    % 先把这一行的数值全部设为 NaN
    % 后面能读到的再覆盖，读不到的就保持 NaN
    X(row, 1:nNumCols) = NaN;
    timeStr{row, 1} = '';
    
    %% 手动按逗号分割，尽量保留空字段
    % 不直接用 strsplit，是因为有些软件会把连续逗号合并，导致缺失位置丢失
    commaPos = find(line == ',');
    startPos = [1, commaPos + 1];
    endPos = [commaPos - 1, length(line)];
    
    parts = {};
    
    for k = 1:length(startPos)
        if startPos(k) > endPos(k)
            parts{k} = '';
        else
            parts{k} = line(startPos(k):endPos(k));
        end
    end
    
    %% 读取时间戳
    if length(parts) >= 1
        timeStr{row, 1} = strrep(parts{1}, '"', '');
    end
    
    %% 读取第2列到第14列的数值
    maxCol = min(length(parts), nTotalCols);
    
for j = 2:maxCol
    
    % 取出当前字段，并去掉双引号
    tempStr = strrep(parts{j}, '"', '');
    
    % 再去掉空格，防止看起来是空，其实里面有空格
    tempStr = strrep(tempStr, ' ', '');
    
    % 如果这个字段本来就是空的，就明确记为 NaN
    if isempty(tempStr)
        X(row, j-1) = NaN;
    else
        % 否则正常转换为数字
        tempVal = str2double(tempStr);
        X(row, j-1) = tempVal;
    end
    
end
    
    %% 如果这一行列数不足，给出提示，但不跳过
    if length(parts) < nTotalCols
        fprintf('提示：CSV第 %d 行列数不足，已保留该行，缺失位置记为 NaN。\n', row + 1);
    end
    
end

%% 6. 关闭文件
fclose(fid);

%% 7. 显示基本信息
[nRows, nNumCols] = size(X);
nCols = nNumCols + 1;

fprintf('\n================ 数据基本信息 ================\n');
fprintf('保留下来的数据行数：%d 行\n', nRows);
fprintf('数据列数：%d 列\n', nCols);

fprintf('\n说明：这里的数据行数不包括表头。\n');
fprintf('CSV文件中的真实行号 = 数据行号 + 1。\n');

%% 8. 显示前5行数据
fprintf('\n================ 前5行数据 ================\n');
fprintf('时间戳\t\t\tTemp_C\tC_in\tQ\tU1\tU2\tU3\tU4\tT1\tT2\tT3\tT4\tC_out\tP_total\n');

showRows = min(5, nRows);

for i = 1:showRows
    
    fprintf('%s\t', timeStr{i});
    
    for j = 1:nNumCols
        fprintf('%.4f\t', X(i, j));
    end
    
    fprintf('\n');
    
end

%% 9. 提取各变量，方便后续检查
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

fprintf('\n变量提取完成。\n');

%% =====================================================
% 第一部分：缺失值检查
%% =====================================================

fprintf('\n================ 一、缺失值检查 ================\n');

missingCount = zeros(nNumCols, 1);
missingRate = zeros(nNumCols, 1);

for j = 1:nNumCols
    
    missIdx = find(isnan(X(:, j)));
    missingCount(j) = length(missIdx);
    missingRate(j) = missingCount(j) / nRows * 100;
    
    fprintf('%s：缺失 %d 个，占 %.4f%%\n', ...
        varNames{j+1}, missingCount(j), missingRate(j));
    
end

%% 检查哪些行存在任意变量缺失
rowMissingFlag = zeros(nRows, 1);

for i = 1:nRows
    for j = 1:nNumCols
        if isnan(X(i, j))
            rowMissingFlag(i) = 1;
        end
    end
end

missingRowIdx = find(rowMissingFlag == 1);

fprintf('\n存在缺失值的行数：%d 行\n', length(missingRowIdx));

if ~isempty(missingRowIdx)
    
    fprintf('前10个存在缺失值的数据行号如下：\n');
    
    showN = min(10, length(missingRowIdx));
    
    for k = 1:showN
        idx = missingRowIdx(k);
        fprintf('数据第 %d 行，时间戳：%s\n', idx, timeStr{idx});
    end
    
end

%% =====================================================
% 第二部分：统计异常值检查，使用 3σ 原则
% 判断规则：数值 < 均值 - 3*标准差 或 数值 > 均值 + 3*标准差
%% =====================================================

fprintf('\n================ 二、统计异常值检查：3σ原则 ================\n');

statOutlierFlag = zeros(nRows, nNumCols);

for j = 1:nNumCols
    
    x = X(:, j);
    validIdx = find(~isnan(x));
    
    if isempty(validIdx)
        fprintf('%s：全是缺失值，无法检查异常。\n', varNames{j+1});
        continue;
    end
    
    xValid = x(validIdx);
    
    mu = mean(xValid);
    sigma = std(xValid);
    
    lower3 = mu - 3 * sigma;
    upper3 = mu + 3 * sigma;
    
    if sigma == 0
        fprintf('%s：标准差为0，暂不判断统计异常。\n', varNames{j+1});
        continue;
    end
    
    badIdx = find(~isnan(x) & (x < lower3 | x > upper3));
    
    for k = 1:length(badIdx)
        statOutlierFlag(badIdx(k), j) = 1;
    end
    
    fprintf('%s：均值 = %.4f，标准差 = %.4f，3σ异常值数量 = %d\n', ...
        varNames{j+1}, mu, sigma, length(badIdx));
    
    if ~isempty(badIdx)
        fprintf('  前5个异常位置：\n');
        showN = min(5, length(badIdx));
        
        for k = 1:showN
            idx = badIdx(k);
            fprintf('  数据第 %d 行，时间戳：%s，数值 = %.4f\n', ...
                idx, timeStr{idx}, x(idx));
        end
    end
    
end

%% =====================================================
% 第三部分：出口粉尘浓度峰值检查
%% =====================================================

fprintf('\n================ 三、出口粉尘浓度峰值检查 ================\n');

validCoutIdx = find(~isnan(C_out_mgNm3));

if isempty(validCoutIdx)
    
    fprintf('出口粉尘浓度全部缺失，无法检查峰值。\n');
    
else
    
    CoutValid = C_out_mgNm3(validCoutIdx);
    
    CoutMean = mean(CoutValid);
    CoutStd = std(CoutValid);
    CoutMax = max(CoutValid);
    CoutMin = min(CoutValid);
    
    peakThreshold = CoutMean + 3 * CoutStd;
    
    peakIdx = find(~isnan(C_out_mgNm3) & C_out_mgNm3 > peakThreshold);
    
    fprintf('出口粉尘浓度最小值：%.4f mg/Nm3\n', CoutMin);
    fprintf('出口粉尘浓度最大值：%.4f mg/Nm3\n', CoutMax);
    fprintf('出口粉尘浓度均值：%.4f mg/Nm3\n', CoutMean);
    fprintf('出口粉尘浓度标准差：%.4f mg/Nm3\n', CoutStd);
    fprintf('峰值判断阈值：均值 + 3σ = %.4f mg/Nm3\n', peakThreshold);
    fprintf('明显峰值数量：%d 个\n', length(peakIdx));
    
    if ~isempty(peakIdx)
        fprintf('前10个明显峰值如下：\n');
        showN = min(10, length(peakIdx));
        
        for k = 1:showN
            idx = peakIdx(k);
            fprintf('数据第 %d 行，时间戳：%s，C_out = %.4f mg/Nm3\n', ...
                idx, timeStr{idx}, C_out_mgNm3(idx));
        end
    end
    
    %% 同时检查是否超过排放目标值 10 mg/Nm3
    exceedIdx = find(~isnan(C_out_mgNm3) & C_out_mgNm3 > 10);
    exceedRate = length(exceedIdx) / length(validCoutIdx) * 100;
    
    fprintf('\n以 C_out_mgNm3 <= 10 作为达标标准：\n');
    fprintf('未达标数据数量：%d 个\n', length(exceedIdx));
    fprintf('未达标比例：%.4f%%\n', exceedRate);
    
end

%% =====================================================
% 第四部分：物理合理性检查
% 这里的范围是工程经验范围，用于初步筛查
% 后续可以根据题目说明或数据分布调整
%% =====================================================

fprintf('\n================ 四、物理合理性检查 ================\n');

% 对13个数值变量设置大致合理范围
% 顺序对应：
% Temp_C, C_in, Q, U1, U2, U3, U4, T1, T2, T3, T4, C_out, P_total

lowerBound = [ ...
    0, ...       % Temp_C，温度一般应为正
    0, ...       % C_in_gNm3，入口粉尘浓度不能为负
    0, ...       % Q_Nm3h，烟气流量不能为负
    0, 0, 0, 0, ...       % 电压不能为负
    1, 1, 1, 1, ...       % 振打周期应大于0
    0, ...       % 出口粉尘浓度不能为负
    0];          % 总电耗不能为负

upperBound = [ ...
    300, ...       % Temp_C，暂设300℃
    100, ...       % C_in_gNm3，暂设100 g/Nm3
    1000000, ...   % Q_Nm3h，暂设100万 Nm3/h
    100, 100, 100, 100, ...    % 电压暂设100 kV
    2000, 2000, 2000, 2000, ... % 振打周期暂设2000 s
    200, ...       % 出口粉尘浓度暂设200 mg/Nm3
    5000];         % 总电耗暂设5000 kW

rangeBadFlag = zeros(nRows, nNumCols);

for j = 1:nNumCols
    
    x = X(:, j);
    
    badIdx = find(~isnan(x) & (x < lowerBound(j) | x > upperBound(j)));
    
    for k = 1:length(badIdx)
        rangeBadFlag(badIdx(k), j) = 1;
    end
    
    fprintf('%s：超出合理范围 [%g, %g] 的数量 = %d\n', ...
        varNames{j+1}, lowerBound(j), upperBound(j), length(badIdx));
    
    if ~isempty(badIdx)
        fprintf('  前5个不合理值：\n');
        showN = min(5, length(badIdx));
        
        for k = 1:showN
            idx = badIdx(k);
            fprintf('  数据第 %d 行，时间戳：%s，数值 = %.4f\n', ...
                idx, timeStr{idx}, x(idx));
        end
    end
    
end

%% =====================================================
% 第五部分：重点检查电压、振打周期、电耗
%% =====================================================

fprintf('\n================ 五、电压、振打周期、电耗重点检查 ================\n');

%% 1. 电压检查
voltageData = [U1_kV, U2_kV, U3_kV, U4_kV];
voltageNames = {'U1_kV', 'U2_kV', 'U3_kV', 'U4_kV'};

fprintf('\n【电压检查】\n');

for j = 1:4
    
    x = voltageData(:, j);
    badIdx = find(~isnan(x) & (x <= 0 | x > 100));
    
    fprintf('%s：小于等于0或大于100kV的数量 = %d\n', voltageNames{j}, length(badIdx));
    
end

%% 2. 振打周期检查
rappingData = [T1_s, T2_s, T3_s, T4_s];
rappingNames = {'T1_s', 'T2_s', 'T3_s', 'T4_s'};

fprintf('\n【振打周期检查】\n');

for j = 1:4
    
    x = rappingData(:, j);
    badIdx = find(~isnan(x) & (x <= 0 | x > 2000));
    
    fprintf('%s：小于等于0或大于2000s的数量 = %d\n', rappingNames{j}, length(badIdx));
    
end

%% 3. 电耗检查
fprintf('\n【总电耗检查】\n');

badPowerIdx = find(~isnan(P_total_kW) & (P_total_kW <= 0 | P_total_kW > 5000));

fprintf('P_total_kW：小于等于0或大于5000kW的数量 = %d\n', length(badPowerIdx));

if ~isempty(badPowerIdx)
    
    fprintf('前5个电耗不合理位置：\n');
    showN = min(5, length(badPowerIdx));
    
    for k = 1:showN
        idx = badPowerIdx(k);
        fprintf('数据第 %d 行，时间戳：%s，P_total = %.4f kW\n', ...
            idx, timeStr{idx}, P_total_kW(idx));
    end
    
end

%% =====================================================
% 第六部分：汇总异常行
%% =====================================================

fprintf('\n================ 六、异常行汇总 ================\n');

totalBadFlag = zeros(nRows, 1);

for i = 1:nRows
    
    % 只要这一行有缺失、统计异常、物理不合理，就标记为异常行
    hasMissing = 0;
    hasStatOutlier = 0;
    hasRangeBad = 0;
    
    for j = 1:nNumCols
        
        if isnan(X(i, j))
            hasMissing = 1;
        end
        
        if statOutlierFlag(i, j) == 1
            hasStatOutlier = 1;
        end
        
        if rangeBadFlag(i, j) == 1
            hasRangeBad = 1;
        end
        
    end
    
    if hasMissing == 1 || hasStatOutlier == 1 || hasRangeBad == 1
        totalBadFlag(i) = 1;
    end
    
end

totalBadIdx = find(totalBadFlag == 1);

fprintf('总异常/可疑行数：%d 行\n', length(totalBadIdx));
fprintf('总异常/可疑行比例：%.4f%%\n', length(totalBadIdx) / nRows * 100);

if ~isempty(totalBadIdx)
    
    fprintf('前10个异常/可疑行如下：\n');
    showN = min(10, length(totalBadIdx));
    
    for k = 1:showN
        idx = totalBadIdx(k);
        fprintf('数据第 %d 行，时间戳：%s\n', idx, timeStr{idx});
    end
    
end

%% =====================================================
% 第七部分：保存检查结果
%% =====================================================

save('A02_check_result.mat', ...
    'timeStr', 'X', 'varNames', ...
    'missingCount', 'missingRate', ...
    'rowMissingFlag', ...
    'statOutlierFlag', ...
    'rangeBadFlag', ...
    'totalBadFlag');

fprintf('\n检查结果已保存为：A02_check_result.mat\n');

fprintf('\n================ 第二步：数据检查完成 ================\n');

clc;
clear;
close all;

%% =====================================================
% A题第三步：数据预处理
% 目标：
% 1. 读取原始 CSV 文件
% 2. 保留缺失值，并将空白单元格识别为 NaN
% 3. 对缺失值进行温和插值处理
% 4. 构造辅助变量
% 5. 构造达标标签
% 6. 保存清洗后的数据
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

nTotalCols = 14;    % 总列数：1列时间戳 + 13列数值
nNumCols = 13;      % 数值列数量

%% 5. 逐行读取数据
% timeStr 保存时间戳
% X 保存13列数值数据
% 空白单元格统一记为 NaN

timeStr = {};
X = [];

row = 0;

while ~feof(fid)
    
    line = fgetl(fid);
    
    if ~ischar(line)
        break;
    end
    
    row = row + 1;
    
    % 先把本行全部设为 NaN
    X(row, 1:nNumCols) = NaN;
    timeStr{row, 1} = '';
    
    %% 手动按逗号分割，保留空字段
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
    
    %% 读取第2列到第14列数值
    maxCol = min(length(parts), nTotalCols);
    
    for j = 2:maxCol
        
        % 去掉双引号和空格
        tempStr = strrep(parts{j}, '"', '');
        tempStr = strrep(tempStr, ' ', '');
        
        % 空白字段明确记为 NaN
        if isempty(tempStr)
            X(row, j-1) = NaN;
        else
            X(row, j-1) = str2double(tempStr);
        end
        
    end
    
end

%% 6. 关闭文件
fclose(fid);

%% 7. 显示基本信息
[nRows, nNumCols] = size(X);

fprintf('\n================ 原始数据读取完成 ================\n');
fprintf('数据行数：%d 行\n', nRows);
fprintf('数值变量列数：%d 列\n', nNumCols);

%% 8. 提取原始变量
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

%% =====================================================
% 第一部分：缺失值统计
%% =====================================================

fprintf('\n================ 一、预处理前缺失值统计 ================\n');

missingCountBefore = zeros(nNumCols, 1);

for j = 1:nNumCols
    
    missingCountBefore(j) = length(find(isnan(X(:, j))));
    
    fprintf('%s：缺失 %d 个\n', ...
        varNames{j+1}, missingCountBefore(j));
    
end

%% 记录原始出口浓度缺失位置
Cout_missing_flag = isnan(C_out_mgNm3);

Cout_missing_idx = find(Cout_missing_flag == 1);

fprintf('\nC_out_mgNm3 原始缺失数量：%d 个\n', length(Cout_missing_idx));

if ~isempty(Cout_missing_idx)
    fprintf('前10个 C_out 缺失位置如下：\n');
    
    showN = min(10, length(Cout_missing_idx));
    
    for k = 1:showN
        idx = Cout_missing_idx(k);
        fprintf('数据第 %d 行，时间戳：%s\n', idx, timeStr{idx});
    end
end

%% =====================================================
% 第二部分：缺失值插值处理
% 说明：
% 1. 对每个数值变量都检查 NaN
% 2. 若有 NaN，则采用前后有效值线性插值
% 3. 若缺失点在开头或结尾，则用最近的有效值补齐
%% =====================================================

fprintf('\n================ 二、缺失值插值处理 ================\n');

X_clean = X;

for j = 1:nNumCols
    
    x = X_clean(:, j);
    
    missIdx = find(isnan(x));
    validIdx = find(~isnan(x));
    
    fprintf('%s：待插值缺失值数量 = %d\n', varNames{j+1}, length(missIdx));
    
    % 如果没有缺失值，直接进入下一列
    if isempty(missIdx)
        continue;
    end
    
    % 如果整列都缺失，无法插值
    if isempty(validIdx)
        fprintf('警告：%s 整列缺失，无法插值。\n', varNames{j+1});
        continue;
    end
    
    % 逐个处理缺失位置
    for k = 1:length(missIdx)
        
        idx = missIdx(k);
        
        % 找前一个有效值
        prevValid = validIdx(validIdx < idx);
        
        % 找后一个有效值
        nextValid = validIdx(validIdx > idx);
        
        if ~isempty(prevValid) && ~isempty(nextValid)
            
            % 情况1：前后都有有效值，做线性插值
            idx1 = prevValid(length(prevValid));
            idx2 = nextValid(1);
            
            x1 = x(idx1);
            x2 = x(idx2);
            
            x(idx) = x1 + (x2 - x1) * (idx - idx1) / (idx2 - idx1);
            
        elseif isempty(prevValid) && ~isempty(nextValid)
            
            % 情况2：缺失在开头，用后一个有效值补
            idx2 = nextValid(1);
            x(idx) = x(idx2);
            
        elseif ~isempty(prevValid) && isempty(nextValid)
            
            % 情况3：缺失在结尾，用前一个有效值补
            idx1 = prevValid(length(prevValid));
            x(idx) = x(idx1);
            
        else
            
            % 理论上不会进入这里，保险起见用均值补
            x(idx) = mean(x(validIdx));
            
        end
        
    end
    
    % 把插值后的这一列放回清洗矩阵
    X_clean(:, j) = x;
    
end

%% 重新提取清洗后的变量
Temp_C_clean        = X_clean(:, 1);
C_in_gNm3_clean     = X_clean(:, 2);
Q_Nm3h_clean        = X_clean(:, 3);

U1_kV_clean         = X_clean(:, 4);
U2_kV_clean         = X_clean(:, 5);
U3_kV_clean         = X_clean(:, 6);
U4_kV_clean         = X_clean(:, 7);

T1_s_clean          = X_clean(:, 8);
T2_s_clean          = X_clean(:, 9);
T3_s_clean          = X_clean(:, 10);
T4_s_clean          = X_clean(:, 11);

C_out_mgNm3_clean   = X_clean(:, 12);
P_total_kW_clean    = X_clean(:, 13);

%% =====================================================
% 第三部分：插值后缺失值复查
%% =====================================================

fprintf('\n================ 三、预处理后缺失值复查 ================\n');

missingCountAfter = zeros(nNumCols, 1);

for j = 1:nNumCols
    
    missingCountAfter(j) = length(find(isnan(X_clean(:, j))));
    
    fprintf('%s：剩余缺失 %d 个\n', ...
        varNames{j+1}, missingCountAfter(j));
    
end

%% 显示前几个被插值的 C_out 结果
if ~isempty(Cout_missing_idx)
    
    fprintf('\nC_out_mgNm3 缺失值插值结果示例：\n');
    
    showN = min(10, length(Cout_missing_idx));
    
    for k = 1:showN
        idx = Cout_missing_idx(k);
        fprintf('数据第 %d 行，时间戳：%s，插值后 C_out = %.4f\n', ...
            idx, timeStr{idx}, C_out_mgNm3_clean(idx));
    end
    
end

%% =====================================================
% 第四部分：构造辅助变量
%% =====================================================

fprintf('\n================ 四、构造辅助变量 ================\n');

%% 1. 平均电压
Avg_U_kV = (U1_kV_clean + U2_kV_clean + U3_kV_clean + U4_kV_clean) / 4;

%% 2. 总电压
Sum_U_kV = U1_kV_clean + U2_kV_clean + U3_kV_clean + U4_kV_clean;

%% 3. 平均振打周期
Avg_T_s = (T1_s_clean + T2_s_clean + T3_s_clean + T4_s_clean) / 4;

%% 4. 总振打周期
Sum_T_s = T1_s_clean + T2_s_clean + T3_s_clean + T4_s_clean;

%% 5. 入口粉尘负荷
% C_in_gNm3 的单位是 g/Nm3
% Q_Nm3h 的单位是 Nm3/h
% 所以 Dust_Load_g_h 的单位是 g/h
Dust_Load_g_h = C_in_gNm3_clean .* Q_Nm3h_clean;

%% 6. 出口粉尘负荷
% C_out_mgNm3 的单位是 mg/Nm3
% 乘以 Q 后得到 mg/h
% 除以 1000 后变成 g/h
Outlet_Load_g_h = C_out_mgNm3_clean .* Q_Nm3h_clean / 1000;

%% 7. 除尘效率
% 入口浓度单位是 g/Nm3
% 出口浓度单位是 mg/Nm3
% 入口浓度乘以1000，统一为 mg/Nm3
Eta = 1 - C_out_mgNm3_clean ./ (C_in_gNm3_clean * 1000);

%% 8. 防止极少数异常导致效率越界
% 正常情况下 Eta 应在 0 到 1 之间
for i = 1:nRows
    if Eta(i) < 0
        Eta(i) = 0;
    end
    
    if Eta(i) > 1
        Eta(i) = 1;
    end
end

fprintf('已构造 Avg_U_kV：平均电压\n');
fprintf('已构造 Sum_U_kV：总电压\n');
fprintf('已构造 Avg_T_s：平均振打周期\n');
fprintf('已构造 Sum_T_s：总振打周期\n');
fprintf('已构造 Dust_Load_g_h：入口粉尘负荷\n');
fprintf('已构造 Outlet_Load_g_h：出口粉尘负荷\n');
fprintf('已构造 Eta：除尘效率\n');

%% =====================================================
% 第五部分：构造达标标签
%% =====================================================

fprintf('\n================ 五、构造达标标签 ================\n');

%% 标签1：按 10 mg/Nm3 达标
IsStandard_10 = zeros(nRows, 1);

for i = 1:nRows
    if C_out_mgNm3_clean(i) <= 10
        IsStandard_10(i) = 1;
    else
        IsStandard_10(i) = 0;
    end
end

%% 标签2：按 50 mg/Nm3 达标
% 由于本数据出口浓度基本集中在 49~50 附近，
% 额外保留一个 50 标准，便于后续探索分析
IsStandard_50 = zeros(nRows, 1);

for i = 1:nRows
    if C_out_mgNm3_clean(i) <= 50
        IsStandard_50(i) = 1;
    else
        IsStandard_50(i) = 0;
    end
end

rate10 = sum(IsStandard_10) / nRows * 100;
rate50 = sum(IsStandard_50) / nRows * 100;

fprintf('按 C_out <= 10 mg/Nm3：达标率 = %.4f%%\n', rate10);
fprintf('按 C_out <= 50 mg/Nm3：达标率 = %.4f%%\n', rate50);

%% =====================================================
% 第六部分：预处理后基础统计
%% =====================================================

fprintf('\n================ 六、预处理后基础统计 ================\n');

fprintf('C_out_mgNm3_clean 最小值：%.4f\n', min(C_out_mgNm3_clean));
fprintf('C_out_mgNm3_clean 最大值：%.4f\n', max(C_out_mgNm3_clean));
fprintf('C_out_mgNm3_clean 平均值：%.4f\n', mean(C_out_mgNm3_clean));

fprintf('P_total_kW_clean 最小值：%.4f\n', min(P_total_kW_clean));
fprintf('P_total_kW_clean 最大值：%.4f\n', max(P_total_kW_clean));
fprintf('P_total_kW_clean 平均值：%.4f\n', mean(P_total_kW_clean));

fprintf('Avg_U_kV 平均值：%.4f\n', mean(Avg_U_kV));
fprintf('Avg_T_s 平均值：%.4f\n', mean(Avg_T_s));
fprintf('Eta 平均值：%.6f\n', mean(Eta));

%% =====================================================
% 第七部分：保存为 MAT 文件
%% =====================================================

save('A03_clean_data.mat', ...
    'timeStr', ...
    'X', 'X_clean', ...
    'Temp_C_clean', 'C_in_gNm3_clean', 'Q_Nm3h_clean', ...
    'U1_kV_clean', 'U2_kV_clean', 'U3_kV_clean', 'U4_kV_clean', ...
    'T1_s_clean', 'T2_s_clean', 'T3_s_clean', 'T4_s_clean', ...
    'C_out_mgNm3_clean', 'P_total_kW_clean', ...
    'Avg_U_kV', 'Sum_U_kV', ...
    'Avg_T_s', 'Sum_T_s', ...
    'Dust_Load_g_h', 'Outlet_Load_g_h', ...
    'Eta', ...
    'IsStandard_10', 'IsStandard_50', ...
    'Cout_missing_flag');

fprintf('\n已保存 MAT 文件：A03_clean_data.mat\n');

%% =====================================================
% 第八部分：保存为 CSV 文件
% 不使用 table / writetable，采用最基础的 fprintf 输出
%% =====================================================

outFile = 'Cement_ESP_Cleaned.csv';

fid_out = fopen(outFile, 'w');

if fid_out == -1
    error('清洗后CSV文件创建失败。');
end

%% 写入表头
fprintf(fid_out, 'timestamp,Temp_C,C_in_gNm3,Q_Nm3h,U1_kV,U2_kV,U3_kV,U4_kV,T1_s,T2_s,T3_s,T4_s,C_out_mgNm3,P_total_kW,Avg_U_kV,Sum_U_kV,Avg_T_s,Sum_T_s,Dust_Load_g_h,Outlet_Load_g_h,Eta,IsStandard_10,IsStandard_50,Cout_missing_flag\n');

%% 逐行写入数据
for i = 1:nRows
    
    fprintf(fid_out, '%s,', timeStr{i});
    
    % 写入清洗后的13个原始变量
    for j = 1:nNumCols
        fprintf(fid_out, '%.6f,', X_clean(i, j));
    end
    
    % 写入辅助变量和标签
    fprintf(fid_out, '%.6f,', Avg_U_kV(i));
    fprintf(fid_out, '%.6f,', Sum_U_kV(i));
    fprintf(fid_out, '%.6f,', Avg_T_s(i));
    fprintf(fid_out, '%.6f,', Sum_T_s(i));
    fprintf(fid_out, '%.6f,', Dust_Load_g_h(i));
    fprintf(fid_out, '%.6f,', Outlet_Load_g_h(i));
    fprintf(fid_out, '%.8f,', Eta(i));
    fprintf(fid_out, '%d,', IsStandard_10(i));
    fprintf(fid_out, '%d,', IsStandard_50(i));

    % 将逻辑型缺失标记转换为普通数字
    if Cout_missing_flag(i) == 1
        missFlag = 1;
    else
        missFlag = 0;

end

fprintf(fid_out, '%d\n', missFlag);
    
end

fclose(fid_out);

fprintf('已保存清洗后 CSV 文件：%s\n', outFile);

fprintf('\n================ 第三步：数据预处理完成 ================\n');

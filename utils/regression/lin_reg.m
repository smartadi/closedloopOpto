function d = lin_reg(y,data,pY,pX,tr) 


%% --- USER INPUTS ---
% Replace with your own data (same length T)
% T = 500;

% T = Train_length;
% rng(0);
% 
% % n-dimensional X (here n = 3)
% n = 10;
% % DataX = [dFkp(2:end,startIdx:endIdx)',1e-6*d.mv(startIdx:endIdx),2*inputs(startIdx:endIdx),];
% 
% DataX = [dFkp(2,startIdx:endIdx)',10*inputs(startIdx:endIdx)];
% DataX = [dFkp(5,startIdx:endIdx)',d.mv(startIdx:endIdx),inputs(startIdx:endIdx),];
% 
% Datay = dFk(startIdx:endIdx)';
% 
% 
DataX = data;
Datay = y;
train_ratio = tr;
Ntr = floor(train_ratio*T);
idx_tr = 1:Ntr; idx_te = (Ntr+1):T;
X_tr = DataX(idx_tr,:);  X_te = DataX(idx_te,:);
y_tr = Datay(idx_tr);    y_te = Datay(idx_te);

% --- Train-only zscore ---
[X_tr_z, muX, sdX] = zscore(X_tr); sdX(sdX<eps)=1;
X_te_z = (X_te - muX) ./ sdX;
[y_tr_z, muy, sdy] = zscore(y_tr); sdy = max(sdy, eps);
y_te_z = (y_te - muy) ./ sdy;

% --- Build lagged design (no leakage) ---
[Phi_tr, y_tr_aligned,maxLag] = buildLagMatrix(y_tr_z, X_tr_z, pY, pX);
[Phi_te, y_te_aligned,maxLag] = buildLagMatrix(y_te_z, X_te_z, pY, pX);

% --- Fit & predict (scaled space) ---
beta         = Phi_tr \ y_tr_aligned;
yhat_tr_scal = Phi_tr * beta;
yhat_te_scal = Phi_te  * beta;

% --- Invert y scaling & align ---
yhat_tr = yhat_tr_scal * sdy + muy;
yhat_te = yhat_te_scal * sdy + muy;
y_tr_raw_aligned = y_tr((maxLag+1):end);
y_te_raw_aligned = y_te((maxLag+1):end);

% Put back onto original time axis (NaNs for first maxLag of each split)
yhat_tr_full = NaN(Ntr,1);           yhat_tr_full((maxLag+1):end) = yhat_tr;
yhat_te_full = NaN(T-Ntr,1);         yhat_te_full((maxLag+1):end) = yhat_te;
yhat_all_full = [yhat_tr_full; yhat_te_full];

% --- METRICS ---
rmse_tr = sqrt(mean((y_tr_raw_aligned - yhat_tr).^2));
rmse_te = sqrt(mean((y_te_raw_aligned - yhat_te).^2));



% %% --- PLOTS: RECONSTRUCTION ---
% % 1) Full-series reconstruction (with NaNs up front)
%
figure('Name','Full Reconstruction','NumberTitle','off');
plot(1:T+1, Datay, 'LineWidth', 1); hold on;
plot(1:T, yhat_all_full, 'LineWidth', 1);
xlabel('t'); ylabel('y');
title('Actual vs Predicted (Full Series)');
legend('Actual y','Predicted \hat{y}','Location','best'); grid on;
%
% 2) Test-slice reconstruction only
figure('Name','Test Reconstruction','NumberTitle','off');
t_test = (Ntr+1):T;  % original-time indices for test region
plot(t_test, Datay(t_test), 'LineWidth', 1); hold on;
plot(t_test, yhat_te_full, 'LineWidth', 1);
xlabel('t'); ylabel('y');
title('Actual vs Predicted (Test Segment)');
legend('Actual y (test)','Predicted \hat{y} (test)','Location','best'); grid on;

% 3) Test residuals
figure('Name','Test Residuals','NumberTitle','off');
plot(t_test, Datay(t_test) - yhat_te_full, 'LineWidth', 1);
xlabel('t'); ylabel('Residual'); grid on;
title('Residuals on Test Segment');

d.beta = beta
d.rmse_tr = rmse_tr;
d.rmse_te = rmse_te;
d.y = yhat_all_full;

d.sdy = sdy;
d.muy = muy;

end

%% Half-violin (shaded) + mean line only

numExp = 10;
nPerExp = 200;

% Example data (replace with yours)
A = cell(numExp,1);
B = cell(numExp,1);
rng(1);
for i = 1:numExp
    A{i} = randn(nPerExp,1) + 0.3*i;
    B{i} = randn(nPerExp,1) + 0.3*i + 0.4;
end

figure; hold on;

halfWidth = 0.3;
alphaFill = 0.5;

colA = [0.25 0.6 0.85];
colB = [0.9  0.35 0.35];

for i = 1:numExp
    % -------- Distribution A (left) --------
    [fA, yA] = ksdensity(A{i});
    fA = fA / max(fA) * halfWidth;

    fill([i - fA, i*ones(size(fA))], ...
         [yA,      fliplr(yA)], ...
         colA, 'FaceAlpha', alphaFill, 'EdgeColor','none');

    % Mean line A
    muA = mean(A{i});
    plot([i-halfWidth, i], [muA muA], 'k-', 'LineWidth', 1.5);

    % -------- Distribution B (right) --------
    [fB, yB] = ksdensity(B{i});
    fB = fB / max(fB) * halfWidth;

    fill([i + fB, i*ones(size(fB))], ...
         [yB,      fliplr(yB)], ...
         colB, 'FaceAlpha', alphaFill, 'EdgeColor','none');

    % Mean line B
    muB = mean(B{i});
    plot([i, i+halfWidth], [muB muB], 'k-', 'LineWidth', 1.5);
end

xlim([0.5 numExp+0.5])
xticks(1:numExp)
xlabel('Experiment')
ylabel('Value')
box on

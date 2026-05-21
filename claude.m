%% =========================================================================
%  SISTEMA CBIR AMB DESCRIPTOR DE COLOR MPEG-7 GoP/GoF
%  Content-Based Image Retrieval - Group of Pictures / Group of Frames
%  =========================================================================
%  Autor  : Enginyer Sènior en Visió per Computador
%  Llengua: Comentaris en català
%  Format : Script MATLAB (compatible amb Live Script .mlx)
%  =========================================================================

clc; clear; close all;

%% =========================================================================
%  SECCIÓ 1: PARÀMETRES GLOBALS
%% =========================================================================

% --- Rutes principals ---
User_root = pwd;
Data_root = fullfile(User_root, 'database', '');

% --- Fitxers d'entrada / sortida ---
Input_filename  = 'input.txt';
Output_filename = 'output.txt';

% --- Dimensions del sistema ---
Num_images = 20;
Candidates = 10;

% --- Base de dades ---
M        = 2000;
Bloc     = 4;
Num_GoPs = M / Bloc;   % 500 GoPs

% --- Format de nom de les imatges de la BD ---
img_format = 'ukbench%05d.jpg';

% --- Dimensió del descriptor final ---
Desc_dim = 128;   % 256 bins -> 128 coeficients d'aproximació Haar nivell 1

% --- Transformada de Haar nivell 1 (fórmula explícita, sense haart()) -----
%
%  L'aproximació de nivell 1 agrupa els bins de 2 en 2:
%    approx_i = (h_{2i-1} + h_{2i}) / sqrt(2)    per i = 1..128
%
%  Usem una funció anònima per evitar fitxers .m externs.
%  Garanteix comportament idèntic a totes les versions de MATLAB.
%
haar1 = @(v) ( double(v(1:2:255)) + double(v(2:2:256)) ) / sqrt(2);
%   Entrada : vector fila o columna de 256 elements
%   Sortida : vector fila de 128 elements

fprintf('=== SISTEMA CBIR GoP/GoF ===\n');
fprintf('Base de dades : %d imatges / %d GoPs\n', M, Num_GoPs);
fprintf('Queries       : %d\n', Num_images);
fprintf('Candidats     : %d\n\n', Candidates);

%% =========================================================================
%  SECCIÓ 2: EXTRACCIÓ DE CARACTERÍSTIQUES DE LA BASE DE DADES
%% =========================================================================
%
%  FONAMENT MATEMÀTIC DE LA INTERSECCIÓ (per què NO s'ha de re-normalitzar):
%  -------------------------------------------------------------------------
%  Siguin h1..h4 els histogrames normalitzats (suma=1) de les 4 imatges.
%  Definim: GoP_inter(i) = min(h1(i), h2(i), h3(i), h4(i))
%
%  Per a QUALSEVOL query q pertanyent al grup:
%    q(i) >= GoP_inter(i)  per a tots els bins i  (per definició del mínim)
%  =>  L1(q, GoP_inter) = sum_i [q(i) - GoP_inter(i)]
%                       = 1 - sum_i(GoP_inter(i))
%                       = 1 - solapament_grup
%
%  Aquesta distància és CONSTANT per a qualsevol de les 4 imatges del grup,
%  i és MÍNIMA per al grup amb major solapament de colors.
%
%  Si re-normalitzem GoP_inter (dividim per la seva suma), modifiquem les
%  proporcions relques dels bins i DESTRUÏM aquesta propietat: la distància
%  ja no és constant ni garantidament mínima per al grup correcte.
%  => La intersecció seria el pitjor mètode (que és el bug que corregim).
%
%  MITJANA i MEDIANA: es normalitzen a suma=1 (comportament estàndard).
%
% =========================================================================

fprintf('--- Extraint descriptors de la base de dades ---\n');

GoP_Intersection = zeros(Num_GoPs, Desc_dim);
GoP_Average      = zeros(Num_GoPs, Desc_dim);
GoP_Median       = zeros(Num_GoPs, Desc_dim);

tic_db = tic;

for g = 0 : Num_GoPs - 1

    hists_bloc = zeros(4, 256);

    for k = 0 : Bloc - 1

        % Número d'imatge 0-based: 0..1999
        img_idx  = g * Bloc + k;
        img_path = fullfile(Data_root, sprintf(img_format, img_idx));
        img_rgb  = imread(img_path);

        % Converteix a HSV (valors en [0,1])
        img_hsv = rgb2hsv(img_rgb);

        % --- Quantització entera robusta (cap bin fora de rang) ---
        % Hue: 16 nivells  -> índex enters [0, 15]
        H_q = min(floor(double(img_hsv(:,:,1)) * 16), 15);
        % Saturation: 4 nivells -> índex enters [0, 3]
        S_q = min(floor(double(img_hsv(:,:,2)) *  4),  3);
        % Value: 4 nivells     -> índex enters [0, 3]
        V_q = min(floor(double(img_hsv(:,:,3)) *  4),  3);

        % Índex 1-based al vector de 256 bins: H*16 + S*4 + V + 1
        lin_idx = H_q * 16 + S_q * 4 + V_q + 1;

        % Histograma normalitzat (suma = 1)
        h = histcounts(lin_idx(:), 1:257);
        hists_bloc(k+1, :) = h / sum(h);
    end

    % -----------------------------------------------------------------------
    %  Agregació GoP: bin a bin sobre les 4 histogrames del bloc
    % -----------------------------------------------------------------------

    % --- INTERSECCIÓ (mínims) — SENSE re-normalitzar ---
    % suma(gop_inter) = solapament <= 1
    % Veure justificació matemàtica a la capçalera d'aquesta secció.
    gop_inter = min(hists_bloc, [], 1);    % 1x256, suma <= 1

    % --- MITJANA (Average) — suma = 1 per construcció ---
    gop_avg = mean(hists_bloc, 1);         % 1x256, suma = 1

    % --- MEDIANA — normalitzada a suma = 1 ---
    gop_med = median(hists_bloc, 1);       % 1x256, suma variable
    s_med   = sum(gop_med);
    if s_med > 0
        gop_med = gop_med / s_med;
    end

    % -----------------------------------------------------------------------
    %  Transformada de Haar nivell 1 (fórmula explícita)
    %  Desa els 128 coeficients d'aproximació
    % -----------------------------------------------------------------------
    GoP_Intersection(g+1, :) = haar1(gop_inter);
    GoP_Average     (g+1, :) = haar1(gop_avg);
    GoP_Median      (g+1, :) = haar1(gop_med);

    if mod(g+1, 50) == 0
        fprintf('  GoP %3d/%d processats...\n', g+1, Num_GoPs);
    end
end

fprintf('  Base de dades extreta en %.2f s\n\n', toc(tic_db));

%% =========================================================================
%  SECCIÓ 3: PROCESSAMENT DE LES QUERIES
%% =========================================================================
%
%  Cada query és una imatge individual. El descriptor és l'histograma HSV
%  normalitzat (suma=1) + Haar nivell 1. Idèntic al pipeline de la BD.
%
%  NOTA "vigila amb les que es confonen lleugerament":
%    En UKBench, grups consecutius de 4 imatges poden tenir colors similars
%    (p.ex. grup 10 i grup 11 fotografien objectes del mateix color).
%    El grup real de la query s'extreu del NÚMERO del nom de fitxer
%    (no de la posició al bucle), garantint que no hi hagi desfasament
%    ni confusió en cas que input.txt no estigui ordenat.
%
% =========================================================================

fprintf('--- Extraint descriptors de les queries ---\n');

fid = fopen(fullfile(User_root, Input_filename), 'r');
if fid == -1
    error('No s''ha pogut obrir: %s', fullfile(User_root, Input_filename));
end
raw_lines    = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
fclose(fid);
query_names  = strtrim(raw_lines{1});
query_names  = query_names(~cellfun('isempty', query_names));  % elimina línies buides

if numel(query_names) < Num_images
    error('input.txt conté %d noms; se n''esperen %d.', numel(query_names), Num_images);
end
query_names = query_names(1:Num_images);

Q_desc   = zeros(Num_images, Desc_dim);
Q_groups = zeros(Num_images, 1);   % grup real (0-based) de cada query

for q = 1 : Num_images

    % Cerca la imatge primer a User_root, després a Data_root
    q_path = fullfile(User_root, query_names{q});
    if ~exist(q_path, 'file')
        q_path = fullfile(Data_root, query_names{q});
    end

    q_rgb = imread(q_path);
    q_hsv = rgb2hsv(q_rgb);

    % Quantització entera (idèntica a la BD)
    H_q = min(floor(double(q_hsv(:,:,1)) * 16), 15);
    S_q = min(floor(double(q_hsv(:,:,2)) *  4),  3);
    V_q = min(floor(double(q_hsv(:,:,3)) *  4),  3);

    lin_idx = H_q * 16 + S_q * 4 + V_q + 1;
    h       = histcounts(lin_idx(:), 1:257);
    h_norm  = h / sum(h);            % suma = 1

    Q_desc(q, :) = haar1(h_norm);   % 128 coeficients d'aproximació Haar

    % Grup real: número extret del final del nom de fitxer
    % (regexp '\d+$' agafa la seqüència de dígits al final del basename)
    [~, q_base, ~]  = fileparts(query_names{q});
    q_num           = str2double(regexp(q_base, '\d+$', 'match', 'once'));
    Q_groups(q)     = floor(q_num / Bloc);   % grup 0-based (0..499)
end

fprintf('  %d queries processades.\n\n', Num_images);

%% =========================================================================
%  SECCIÓ 4: CÀLCUL DE DISTÀNCIES I SELECCIÓ DE CANDIDATS
%% =========================================================================

fprintf('--- Calculant distàncies i seleccionant candidats ---\n');

metode_noms = {'Intersection', 'Average', 'Median'};
dist_noms   = {'L1', 'L2'};
GoP_mats    = {GoP_Intersection, GoP_Average, GoP_Median};

% idx_candidats{m,d} -> matriu (Num_images x Candidates) índexs 1-based
idx_candidats = cell(3, 2);

for m = 1 : 3
    GoP_mat = GoP_mats{m};

    for d = 1 : 2
        cand_mat = zeros(Num_images, Candidates);

        for q = 1 : Num_images
            q_vec = Q_desc(q, :);   % 1x128

            % Distàncies de la query a tots els GoPs
            dif = GoP_mat - repmat(q_vec, Num_GoPs, 1);   % 500x128
            if d == 1
                dists = sum(abs(dif), 2);          % L1
            else
                dists = sqrt(sum(dif .^ 2, 2));    % L2
            end

            % Ordena GoPs de menor (més similar) a major distància
            [~, sorted_gops] = sort(dists, 'ascend');
            % sorted_gops(i) = índex 1-based del GoP (1..500)

            % --- Mapeig d'índexs sense desfasament ---
            % GoP g (1-based, 1..500):
            %   imatges 0-based: (g-1)*4, (g-1)*4+1, (g-1)*4+2, (g-1)*4+3
            %   imatges 1-based: (g-1)*4+1 .. (g-1)*4+4
            cands = [];
            gi    = 1;
            while numel(cands) < Candidates
                gop_1b  = sorted_gops(gi);                   % 1-based GoP
                imgs_1b = (gop_1b - 1) * Bloc + (1:Bloc);   % 4 imatges 1-based
                cands   = [cands, imgs_1b];                  %#ok<AGROW>
                gi      = gi + 1;
            end

            cand_mat(q, :) = cands(1:Candidates);  % primers 10 (1-based MATLAB)
        end

        idx_candidats{m, d} = cand_mat;
    end
end

fprintf('  Candidats seleccionats.\n\n');

%% =========================================================================
%  SECCIÓ 5: AVALUACIÓ (Precision, Recall, F-score)
%% =========================================================================
%
%  LÒGICA D'ENCERT (crítica):
%    Grup de la query   = Q_groups(q)                  (0-based, secció 3)
%    Grup del candidat  = floor( (idx_1based - 1) / 4 )  (0-based)
%    Encert si coincideixen.
%
%    Nombre de rellevants = 4 (totes les imatges del grup de la query,
%    inclosa la pròpia query ja que és a la BD).
%
% =========================================================================

fprintf('--- Avaluant resultats ---\n');

colors_metodes = {'r', 'g', 'b'};

prec_all  = cell(3, 2);
rec_all   = cell(3, 2);
res_max_f = zeros(3, 2);

for m = 1 : 3
    for d = 1 : 2
        cand_mat = idx_candidats{m, d};
        prec_mat = zeros(Num_images, Candidates);
        rec_mat  = zeros(Num_images, Candidates);

        for q = 1 : Num_images
            q_group        = Q_groups(q);  % grup real 0-based
            num_rellevants = Bloc;         % 4 imatges rellevants

            encerts = 0;
            for k = 1 : Candidates
                % Grup del candidat k (0-based)
                cand_group = floor((cand_mat(q, k) - 1) / Bloc);

                if cand_group == q_group
                    encerts = encerts + 1;
                end

                prec_mat(q, k) = encerts / k;
                rec_mat(q, k)  = encerts / num_rellevants;
            end
        end

        avg_prec = mean(prec_mat, 1);   % 1x10
        avg_rec  = mean(rec_mat,  1);   % 1x10
        prec_all{m, d} = avg_prec;
        rec_all{m, d}  = avg_rec;

        % F-score (evita divisió per zero)
        denom   = avg_prec + avg_rec;
        f_score = zeros(1, Candidates);
        nz      = denom > 0;
        f_score(nz) = 2 * avg_prec(nz) .* avg_rec(nz) ./ denom(nz);

        res_max_f(m, d) = max(f_score);
        fprintf('  %-14s | %s | Max F-score = %.4f\n', ...
                metode_noms{m}, dist_noms{d}, res_max_f(m, d));
    end
end

fprintf('\n');

%% =========================================================================
%  SECCIÓ 6: INTERFÍCIE VISUAL I GENERACIÓ DE GRÀFIQUES
%% =========================================================================

fprintf('--- Generant figura ---\n');

markers = {'o', 's', '^'};

% Malla per als contorns de l'F-score (fons de les gràfiques P-R)
pv = linspace(0.01, 1, 200);
rv = linspace(0.01, 1, 200);
[P_m, R_m] = meshgrid(pv, rv);
F_m   = 2 * P_m .* R_m ./ (P_m + R_m);
f_lev = 0.1 : 0.1 : 0.9;

fig = figure('Name', 'Avaluació SCD GoP', 'Color', 'white', ...
             'Position', [50, 50, 1400, 680]);

% ---- Subplot 1: Distància L1 ---------------------------------------------
ax1 = subplot(1, 3, 1);
hold(ax1, 'on');
[C1, h1c] = contour(ax1, rv, pv, F_m, f_lev, ...
    'LineColor', [0.82 0.82 0.82], 'LineStyle', '--');
clabel(C1, h1c, 'FontSize', 7, 'Color', [0.55 0.55 0.55]);

for m = 1 : 3
    rc = rec_all{m, 1};
    pr = prec_all{m, 1};
    plot(ax1, rc, pr, [colors_metodes{m}, '-'], ...
        'Marker', markers{m}, 'LineWidth', 1.8, 'MarkerSize', 7, ...
        'DisplayName', metode_noms{m});
    for k = 1 : Candidates
        text(ax1, rc(k)+0.008, pr(k)+0.008, num2str(k), ...
            'FontSize', 7, 'Color', colors_metodes{m}, ...
            'HorizontalAlignment', 'left');
    end
end
hold(ax1, 'off');
xlabel(ax1, 'Recall'); ylabel(ax1, 'Precision');
title(ax1, 'Precision-Recall  (L1 / Manhattan)');
legend(ax1, 'Location', 'northeast', 'FontSize', 8);
xlim(ax1, [0 1]); ylim(ax1, [0 1]);
grid(ax1, 'on'); axis(ax1, 'square');

% ---- Subplot 2: Distància L2 ---------------------------------------------
ax2 = subplot(1, 3, 2);
hold(ax2, 'on');
[C2, h2c] = contour(ax2, rv, pv, F_m, f_lev, ...
    'LineColor', [0.82 0.82 0.82], 'LineStyle', '--');
clabel(C2, h2c, 'FontSize', 7, 'Color', [0.55 0.55 0.55]);

for m = 1 : 3
    rc = rec_all{m, 2};
    pr = prec_all{m, 2};
    plot(ax2, rc, pr, [colors_metodes{m}, '-'], ...
        'Marker', markers{m}, 'LineWidth', 1.8, 'MarkerSize', 7, ...
        'DisplayName', metode_noms{m});
    for k = 1 : Candidates
        text(ax2, rc(k)+0.008, pr(k)+0.008, num2str(k), ...
            'FontSize', 7, 'Color', colors_metodes{m}, ...
            'HorizontalAlignment', 'left');
    end
end
hold(ax2, 'off');
xlabel(ax2, 'Recall'); ylabel(ax2, 'Precision');
title(ax2, 'Precision-Recall  (L2 / Euclidiana)');
legend(ax2, 'Location', 'northeast', 'FontSize', 8);
xlim(ax2, [0 1]); ylim(ax2, [0 1]);
grid(ax2, 'on'); axis(ax2, 'square');

% ---- Subplot 3: Taula estètica estil IEEE --------------------------------
ax3 = subplot(1, 3, 3);
axis(ax3, 'off');
hold(ax3, 'on');

% Línies horitzontals: top (gruixuda), sota capçalera (prima), bottom (gruixuda)
line_ys = [0.92, 0.74, 0.08];
line_ws = [1.5,  1.1,  1.5];
for li = 1 : 3
    line(ax3, [0.02 0.98], [line_ys(li) line_ys(li)], ...
        'Color', 'k', 'LineWidth', line_ws(li));
end

% Columnes i files
cx = [0.06, 0.46, 0.76];
ry = [0.83, 0.61, 0.44, 0.27];   % fila capçalera + 3 mètodes

% Capçalera
text(ax3, cx(1), ry(1), 'Mètode',      'FontWeight','bold','FontSize',10);
text(ax3, cx(2), ry(1), 'F-max (L1)',  'FontWeight','bold','FontSize',10,'HorizontalAlignment','center');
text(ax3, cx(3), ry(1), 'F-max (L2)',  'FontWeight','bold','FontSize',10,'HorizontalAlignment','center');

% Files de dades (color del mètode)
for m = 1 : 3
    text(ax3, cx(1), ry(m+1), metode_noms{m},                   'FontSize',10,'Color',colors_metodes{m});
    text(ax3, cx(2), ry(m+1), sprintf('%.4f', res_max_f(m,1)),  'FontSize',10,'HorizontalAlignment','center');
    text(ax3, cx(3), ry(m+1), sprintf('%.4f', res_max_f(m,2)),  'FontSize',10,'HorizontalAlignment','center');
end

text(ax3, 0.50, 0.98, 'Taula de Resultats — F-score Màxim', ...
    'FontWeight','bold','FontSize',11, ...
    'HorizontalAlignment','center','VerticalAlignment','top');

xlim(ax3,[0 1]); ylim(ax3,[0 1]);
hold(ax3,'off');
drawnow;
fprintf('  Figura generada.\n\n');

%% =========================================================================
%  ESCRIPTURA DEL FITXER output.txt
%% =========================================================================
%
%  Conté:
%    1. Capçalera amb paràmetres
%    2. Taula resum de F-score màxim
%    3. Vectors P / R / F @ k=1..10 per a cada combinació (mètode x distància)
%
% =========================================================================

fprintf('--- Escrivint %s ---\n', Output_filename);

fout = fopen(fullfile(User_root, Output_filename), 'w');
if fout == -1
    warning('No s''ha pogut crear %s.', Output_filename);
else
    % Capçalera
    fprintf(fout, '=== RESULTATS CBIR GoP/GoF  SCD HSV 256 bins + Haar-1 ===\r\n');
    fprintf(fout, 'Queries: %d  |  Candidats: %d  |  BD: %d imatges / %d GoPs\r\n\r\n', ...
            Num_images, Candidates, M, Num_GoPs);

    % Taula resum F-score màxim
    fprintf(fout, '%-16s  %10s  %10s\r\n', 'Metode', 'Fmax(L1)', 'Fmax(L2)');
    fprintf(fout, '%s\r\n', repmat('-', 1, 40));
    for m = 1 : 3
        fprintf(fout, '%-16s  %10.4f  %10.4f\r\n', ...
                metode_noms{m}, res_max_f(m,1), res_max_f(m,2));
    end
    fprintf(fout, '\r\n');

    % Detall P/R/F per combinació
    for m = 1 : 3
        for d = 1 : 2
            pr = prec_all{m, d};
            rc = rec_all{m, d};
            dn = pr + rc;
            fs = zeros(1, Candidates);
            fs(dn>0) = 2 * pr(dn>0) .* rc(dn>0) ./ dn(dn>0);

            fprintf(fout, '--- %s | %s ---\r\n', metode_noms{m}, dist_noms{d});
            fprintf(fout, '%6s', 'k');
            for k=1:Candidates; fprintf(fout,'%9d',k);      end; fprintf(fout,'\r\n');
            fprintf(fout, '%6s', 'Prec');
            for k=1:Candidates; fprintf(fout,'%9.4f',pr(k)); end; fprintf(fout,'\r\n');
            fprintf(fout, '%6s', 'Rec');
            for k=1:Candidates; fprintf(fout,'%9.4f',rc(k)); end; fprintf(fout,'\r\n');
            fprintf(fout, '%6s', 'F');
            for k=1:Candidates; fprintf(fout,'%9.4f',fs(k)); end; fprintf(fout,'\r\n\r\n');
        end
    end

    fclose(fout);
    fprintf('  Resultat desat a: %s\n\n', fullfile(User_root, Output_filename));
end

%% =========================================================================
%  SECCIÓ 7: COST COMPUTACIONAL
%% =========================================================================

fprintf('--- Mesurant cost computacional ---\n');

% Temps d'extracció + classificació d'1 imatge (L1 + Average)
test_path = fullfile(Data_root, sprintf(img_format, 0));
tic_q = tic;
    t_rgb = imread(test_path);
    t_hsv = rgb2hsv(t_rgb);
    H_t   = min(floor(double(t_hsv(:,:,1))*16), 15);
    S_t   = min(floor(double(t_hsv(:,:,2))* 4),  3);
    V_t   = min(floor(double(t_hsv(:,:,3))* 4),  3);
    li_t  = H_t*16 + S_t*4 + V_t + 1;
    ht    = histcounts(li_t(:), 1:257);
    ht_n  = ht / sum(ht);
    qt_d  = haar1(ht_n);
    dists_t = sum(abs(GoP_Average - repmat(qt_d, Num_GoPs, 1)), 2);
    [~, sg] = sort(dists_t, 'ascend');
    cc = []; gi = 1;
    while numel(cc) < Candidates
        cc = [cc, (sg(gi)-1)*Bloc + (1:Bloc)]; %#ok<AGROW>
        gi = gi + 1;
    end
t_query = toc(tic_q);

% Benchmark FFT
tic_fft = tic;
    fft(rand(1024*1024, 1));
t_fft = toc(tic_fft);

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════╗\n');
fprintf('║          COST COMPUTACIONAL                      ║\n');
fprintf('╠══════════════════════════════════════════════════╣\n');
fprintf('║  Extracció + classif. (1 imatge, L1 + Avg)       ║\n');
fprintf('║    Temps  : %8.4f s                           ║\n', t_query);
fprintf('╠══════════════════════════════════════════════════╣\n');
fprintf('║  Benchmark FFT  rand(1024x1024)                  ║\n');
fprintf('║    Temps  : %8.4f s                           ║\n', t_fft);
fprintf('╠══════════════════════════════════════════════════╣\n');
fprintf('║  Ràtio query/FFT : %6.2fx                        ║\n', t_query/t_fft);
fprintf('╚══════════════════════════════════════════════════╝\n\n');

fprintf('=== FI DEL SISTEMA CBIR GoP/GoF ===\n');

% =========================================================================
%  FI DEL SCRIPT
% =========================================================================
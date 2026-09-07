function FIN = compute_financial_metrics(capex, cfAnnual, opts)
%COMPUTE_FINANCIAL_METRICS  VAN, TIR e tempo di ritorno per membro, a flussi
%   annui costanti su un orizzonte dichiarato.
%
%   E' l'ultimo pezzo che mancava alla catena economica: MAIN.m si fermava al
%   flusso di cassa ANNUO e non lo attualizzava mai, cosi' [MEMBRI].quota_inv_EUR
%   e [INVESTIMENTO].tasso_sconto restavano dichiarati e mai letti.
%
%   IL PERIMETRO: L'INVESTIMENTO COMPLETO, NON LA SOLA CER
%     Il flusso che il chiamante passa deve essere quello dell'INVESTIMENTO nel
%     suo insieme - risparmio in bolletta da autoconsumo, vendita
%     dell'eccedenza, quota di incentivo CER, meno OPEX e rata del mutuo - e non
%     il solo incentivo. La ragione non e' di gusto: l'autoconsumo dietro
%     contatore e' la voce dominante per un prosumer, e imputare la quota
%     d'investimento (42.000 EUR per l'industria di CER_2_5_0) a un flusso che
%     contiene solo l'incentivo darebbe VAN grandemente negativi e un tempo di
%     ritorno oltre la vita utile per impianti che in realta' rientrano in pochi
%     anni. Quei 42.000 EUR comprano il fotovoltaico, non l'adesione alla CER.
%
%     Questa funzione non lo sa e non puo' saperlo: riceve numeri. La
%     costruzione del flusso sta in MAIN.m par. 3v, ed e' li' che va guardata se
%     un risultato sorprende.
%
%   FLUSSI COSTANTI, E LE TRE IPOTESI CHE RESTANO SPENTE
%     Il flusso annuo e' preso costante per tutta la vita utile. La scheda
%     dichiara anche escalation_energia (3%), inflazione_opex (5%) e
%     degrado_pv_pct_anno (0,50%), che qui NON sono applicati e finiscono nel
%     registro delle ipotesi: sono tre parametri che nessuno ha ancora tarato e
%     che, moltiplicati fra loro su vent'anni, muovono il VAN piu' di quanto
%     muova la scelta del metodo di ripartizione - cioe' proprio la grandezza
%     che questo progetto vuole confrontare.
%
%     Chi volesse accenderli li passa da opts: sono argomenti, non costanti
%     sepolte. Il caso base resta a flussi costanti, dichiarato.
%
%     Una nota che vale la pena fissare: l'escalation NON andrebbe comunque
%     applicata alla quota di incentivo. La TIP e' una tariffa regolata e si
%     muove al CONTRARIO del prezzo dell'energia, per via del max(0; 180 - Pz)
%     della formula 3.1: indicizzarla al +3% annuo sarebbe sbagliato due volte.
%
%   L'ORIZZONTE
%     Vent'anni di default, che e' insieme il dato di scheda
%     ([INVESTIMENTO].vita_utile_anni) e il periodo di incentivazione previsto
%     dalle Regole Operative GSE del 16 luglio 2025 par. 2.2.1 ("il periodo di
%     incentivazione, ove previsto, ha una durata pari a 20 anni"). Le due cose
%     coincidono per fortuna, non per costruzione: se un domani la scheda
%     dichiarasse una vita utile diversa dal periodo incentivato, il flusso
%     costante smetterebbe di essere una semplificazione innocua, perche' dopo
%     il ventesimo anno la quota di incentivo sparisce.
%     (optimizer_PV.m usa 30 anni scritti a mano: e' un altro ramo del progetto,
%     e la scheda vince.)
%
%   I CASI DEGENERI, CHE QUI SONO LA REGOLA E NON L'ECCEZIONE
%     Una CER ha per costruzione membri che non investono nulla: in CER_2_5_0
%     sono due su sette. Per loro il TIR non e' "molto alto", e' INDEFINITO -
%     non esiste un tasso che annulli un flusso tutto positivo - e il tempo di
%     ritorno e' zero perche' non c'e' nulla da ritornare. Restituire un numero
%     grande al posto di NaN significherebbe stampare in tesi un rendimento che
%     nessuno ha realizzato.
%
%     Ogni cella porta quindi una nota, e chi stampa la tabella la usa:
%       ""                 caso ordinario
%       "nessun investimento"   capex = 0: VAN = rendita, TIR indefinito
%       "non rientra"           flusso <= 0: nessun ritorno, payback infinito
%       "oltre vita utile"      payback calcolabile ma fuori orizzonte
%
%   INPUT
%     capex     [n x 1]  investimento all'anno 0, per membro          [EUR]
%     cfAnnual  [n x k]  flusso di cassa annuo, per membro e per metodo
%                        di ripartizione (k colonne = k metodi)   [EUR/anno]
%     opts      struct opzionale:
%                 .discountRate    tasso di sconto (def. 0.04)          [-]
%                 .lifetimeYears   orizzonte in anni (def. 20)
%                 .escalation      crescita annua dei ricavi (def. 0)   [-]
%                 .opexInflation   inflazione OPEX (def. 0, non usata a
%                                  flussi costanti: registrata come ipotesi)
%                 .degradation     degrado annuo del PV (def. 0)        [-]
%                 .methodNames     [1 x k] nomi delle colonne, per le note
%                 .validateSelf    auto-test analitico (def. true)
%
%   OUTPUT (struct FIN)
%     .NPV          [n x k]  valore attuale netto                     [EUR]
%     .IRR          [n x k]  tasso interno di rendimento; NaN se indefinito [-]
%     .payback      [n x k]  tempo di ritorno semplice; Inf se non rientra [anni]
%     .note         [n x k]  string, vedi sopra
%     .discountRate scalare  il tasso effettivamente usato
%     .lifetimeYears scalare l'orizzonte effettivamente usato
%     .assumptions  table    Id | Voce | Valore | ComeRimuoverla
%
%   Vedi anche: irr_bisection, opts_from_config, MAIN

    if nargin < 3 || isempty(opts), opts = struct(); end

    % Quali campi sono ARRIVATI dalla scheda e quali sono default: serve al
    % registro delle ipotesi, che deve distinguere "vale 0,04 perche' lo dice la
    % scheda" da "vale 0,04 perche' nessuno l'ha detto". Stessa convenzione di
    % fairness_indicators_lem.m.
    fornito = struct( ...
        'discountRate',  isfield(opts, 'discountRate'), ...
        'lifetimeYears', isfield(opts, 'lifetimeYears'), ...
        'escalation',    isfield(opts, 'escalation'), ...
        'opexInflation', isfield(opts, 'opexInflation'), ...
        'degradation',   isfield(opts, 'degradation'));

    if ~fornito.discountRate,  opts.discountRate  = 0.04; end
    if ~fornito.lifetimeYears, opts.lifetimeYears = 20;   end
    if ~fornito.escalation,    opts.escalation    = 0;    end
    if ~fornito.opexInflation, opts.opexInflation = 0;    end
    if ~fornito.degradation,   opts.degradation   = 0;    end

    r = double(opts.discountRate);
    T = round(double(opts.lifetimeYears));

    if ~(isfinite(r) && r > -1)
        error('compute_financial_metrics:tassoNonValido', ...
              'Tasso di sconto %g non utilizzabile: serve un valore finito > -1.', r);
    end
    if ~(isfinite(T) && T >= 1)
        error('compute_financial_metrics:orizzonteNonValido', ...
              'Vita utile %g anni: serve un intero >= 1.', opts.lifetimeYears);
    end

    capex = double(capex(:));
    n     = numel(capex);
    if size(cfAnnual, 1) ~= n
        error('compute_financial_metrics:sizeMismatch', ...
              ['capex ha %d righe e cfAnnual ne ha %d: devono essere lo stesso ' ...
               'elenco di membri, nello stesso ordine.'], n, size(cfAnnual, 1));
    end
    k = size(cfAnnual, 2);

    % Il fattore che moltiplica il flusso di ogni anno. A escalation e degrado
    % nulli e' l'annualita' classica (1-(1+r)^-T)/r; tenerlo in forma di somma
    % esplicita evita di dover scrivere due formule quando i due parametri sono
    % accesi, e su vent'anni non costa nulla.
    anni    = (1:T).';
    crescita = (1 + opts.escalation).^(anni - 1) .* (1 - opts.degradation).^(anni - 1);
    sconto   = (1 + r).^(-anni);
    annualita = sum(crescita .* sconto);

    FIN.NPV     = nan(n, k);
    FIN.IRR     = nan(n, k);
    FIN.payback = nan(n, k);
    FIN.note    = strings(n, k);

    for j = 1:k
        cf = double(cfAnnual(:, j));
        for i = 1:n
            [FIN.NPV(i,j), FIN.IRR(i,j), FIN.payback(i,j), FIN.note(i,j)] = ...
                local_una_posizione(capex(i), cf(i), r, T, crescita, annualita);
        end
    end

    FIN.discountRate  = r;
    FIN.lifetimeYears = T;

    % --- Registro delle ipotesi ancora attive --------------------------------
    reg = struct('id', {}, 'voce', {}, 'valore', {}, 'rimozione', {});
    if ~fornito.discountRate
        reg = local_note(reg, 1, 'Tasso di sconto', ...
                         sprintf('%.3f di default ([INVESTIMENTO].tasso_sconto non letto)', r), ...
                         'compilare tasso_sconto nello scenario economico');
    end
    if ~fornito.lifetimeYears
        reg = local_note(reg, 2, 'Orizzonte di valutazione', ...
                         sprintf('%d anni di default', T), ...
                         'compilare vita_utile_anni nello scenario economico');
    end
    if opts.escalation == 0
        reg = local_note(reg, 3, 'Escalation del prezzo dell''energia', ...
                         'NON applicata: ricavi costanti per tutta la vita utile', ...
                         'passare opts.escalation (ma non va applicata alla TIP)');
    end
    if opts.opexInflation == 0
        reg = local_note(reg, 4, 'Inflazione degli OPEX', ...
                         'NON applicata: costi di esercizio costanti', ...
                         'passare opts.opexInflation');
    end
    if opts.degradation == 0
        reg = local_note(reg, 5, 'Degrado del fotovoltaico', ...
                         'NON applicato: la produzione oraria e'' costante su tutta la vita utile', ...
                         'passare opts.degradation');
    end

    colonneReg = {'Id', 'Voce', 'Valore', 'ComeRimuoverla'};
    if isempty(reg)
        FIN.assumptions = table(zeros(0,1), strings(0,1), strings(0,1), strings(0,1), ...
                                'VariableNames', colonneReg);
    else
        FIN.assumptions = sortrows(table([reg.id].', string({reg.voce}).', ...
                                         string({reg.valore}).', string({reg.rimozione}).', ...
                                         'VariableNames', colonneReg), 'Id');
    end

    if ~isfield(opts, 'validateSelf') || opts.validateSelf
        local_validate_self();
    end
end


% ===========================================================================
%  FUNZIONI LOCALI
% ===========================================================================

function [npv, tir, payback, nota] = local_una_posizione(capex, cf, r, T, crescita, annualita)
%LOCAL_UNA_POSIZIONE  I tre indicatori per un membro e un metodo.

    npv = -capex + cf * annualita;
    nota = "";

    % --- Chi non ha investito nulla -----------------------------------------
    % Non e' un caso limite da tollerare: e' meta' di una CER. Il VAN e' la
    % rendita attualizzata della sua quota, il TIR non esiste (nessun tasso
    % annulla un flusso tutto dello stesso segno) e il ritorno e' immediato
    % perche' non c'e' un esborso da recuperare.
    if capex == 0
        tir     = NaN;
        payback = 0;
        nota    = "nessun investimento";
        return
    end

    % --- Flusso non positivo: non rientra ------------------------------------
    if cf <= 0
        tir     = NaN;
        payback = Inf;
        nota    = "non rientra";
        return
    end

    tir = irr_bisection([-capex; cf * crescita]);

    % Tempo di ritorno SEMPLICE, non attualizzato: e' l'anno in cui i flussi
    % cumulati coprono l'esborso. A flussi costanti coincide con capex/cf, ma la
    % forma cumulata regge anche con escalation e degrado accesi.
    cumulato = cumsum(cf * crescita);
    primo    = find(cumulato >= capex, 1);

    if isempty(primo)
        % Rientra dopo l'orizzonte, oppure mai: distinguere i due casi
        % richiederebbe di estrapolare oltre la vita utile, che e' proprio la
        % cosa che non si vuole fare. Si dice quel che si sa.
        payback = Inf;
        nota    = "oltre vita utile";
        return
    end

    % Interpolazione lineare dentro l'anno, cosi' il numero non e' a scalini.
    primaCf = cumulato(primo) - cf * crescita(primo);
    payback = (primo - 1) + (capex - primaCf) / (cf * crescita(primo));

    if payback > T
        nota = "oltre vita utile";
    end
end


function reg = local_note(reg, id, voce, valore, rimozione)
%LOCAL_NOTE  Aggiunge una voce al registro delle ipotesi ancora attive.
    reg(end+1) = struct('id', id, 'voce', voce, 'valore', valore, ...
                        'rimozione', rimozione);
end


function o = local_o(varargin)
%LOCAL_O  Opzioni per l'auto-test, con validateSelf gia' spento.
%   Spegnerlo e' obbligatorio: l'auto-test chiama la funzione, che rieseguirebbe
%   l'auto-test, che la richiamerebbe.
    o = struct('validateSelf', false);
    for i = 1:2:numel(varargin)
        o.(varargin{i}) = varargin{i+1};
    end
end


function local_validate_self()
%LOCAL_VALIDATE_SELF  Auto-test analitico su casi costruiti a penna.
%
%   Convenzione del progetto (cer_reduction_factor.m, cer_tip_bracket_power.m):
%   niente cartella di test, l'auto-test sta nel modulo ed e' acceso di default.
%
%   I casi 3 e 4 sono quelli che contano: sono i due modi in cui questa funzione
%   potrebbe stampare in tesi un numero che nessuno ha realizzato.

    tol = 1e-9;
    o   = local_o();

    % --- 1) L'annualita', a mano --------------------------------------------
    % 1.000 EUR/anno per 10 anni al 5%: fattore 7,721735... su 1.000 di esborso.
    F = compute_financial_metrics(1000, 1000, ...
            local_o('discountRate', 0.05, 'lifetimeYears', 10));
    atteso = -1000 + 1000 * (1 - 1.05^-10) / 0.05;
    assert(abs(F.NPV - atteso) < tol, ...
           'compute_financial_metrics: il VAN non e'' la rendita attualizzata');
    assert(abs(F.payback - 1) < tol, ...
           'compute_financial_metrics: 1.000 recuperati da 1.000/anno tornano in un anno');

    % --- 2) Il TIR annulla il VAN -------------------------------------------
    % L'invariante piu' forte: qualunque cosa faccia la bisezione, al tasso che
    % restituisce il valore attuale deve essere nullo.
    %
    % La soglia e' RELATIVA all'esborso, e non e' pigrizia. irr_bisection si
    % ferma quando l'INTERVALLO di tassi scende sotto 1e-8, e su vent'anni
    % dNPV/dr vale qualche decina di migliaia: il residuo in euro e' quindi
    % dell'ordine di 1e-4, per costruzione. Una soglia assoluta stretta qui non
    % misurerebbe questa funzione, misurerebbe la tolleranza di irr_bisection -
    % e fallirebbe senza che nulla sia rotto.
    capex2 = 10000;
    F2 = compute_financial_metrics(capex2, 1500, ...
            local_o('discountRate', 0.04, 'lifetimeYears', 20));
    G  = compute_financial_metrics(capex2, 1500, ...
            local_o('discountRate', F2.IRR, 'lifetimeYears', 20));
    assert(abs(G.NPV) < 1e-6 * capex2, ...
           'compute_financial_metrics: al tasso pari al TIR il VAN deve annullarsi');

    % --- 3) Chi non investe: TIR INDEFINITO, non enorme ---------------------
    F3 = compute_financial_metrics(0, 500, o);
    assert(isnan(F3.IRR), ...
           ['compute_financial_metrics: senza investimento il TIR e'' indefinito. ' ...
            'Se qui esce un numero, finisce in tesi come rendimento di un ' ...
            'membro che non ha speso nulla.']);
    assert(F3.payback == 0 && F3.note == "nessun investimento", ...
           'compute_financial_metrics: senza investimento il ritorno e'' immediato e va marcato');
    assert(F3.NPV > 0, 'compute_financial_metrics: un flusso positivo senza esborso vale');

    % --- 4) Payback oltre la vita utile: marcato, non taciuto ---------------
    F4 = compute_financial_metrics(10000, 100, local_o('lifetimeYears', 20));
    assert(F4.note == "oltre vita utile" && isinf(F4.payback), ...
           ['compute_financial_metrics: 10.000 EUR recuperati a 100 EUR/anno non ' ...
            'rientrano in vent''anni, e va detto invece che restituire 100']);
    assert(F4.NPV < 0, 'compute_financial_metrics: quel caso deve avere VAN negativo');

    % --- 5) Flusso nullo o negativo -----------------------------------------
    F5 = compute_financial_metrics(5000, -10, o);
    assert(isnan(F5.IRR) && isinf(F5.payback) && F5.note == "non rientra", ...
           'compute_financial_metrics: con flusso negativo non c''e'' ritorno');

    % --- 6) Piu' membri e piu' metodi in una chiamata sola ------------------
    F6 = compute_financial_metrics([1000; 0], [100 200; 50 60], o);
    assert(isequal(size(F6.NPV), [2 2]) && isequal(size(F6.note), [2 2]), ...
           'compute_financial_metrics: la forma [n x k] non e'' rispettata');
    assert(all(isnan(F6.IRR(2, :))), ...
           'compute_financial_metrics: la riga senza investimento resta indefinita su ogni metodo');

    % --- 7) Il registro delle ipotesi si popola -----------------------------
    assert(height(F5.assumptions) >= 3, ...
           ['compute_financial_metrics: escalation, inflazione OPEX e degrado ' ...
            'non applicati devono comparire fra le ipotesi attive']);
end

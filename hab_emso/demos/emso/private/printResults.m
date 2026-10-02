function printResults(res, names)
%PRINTRESULTS One line per emitter: method, error and CEP (or reason).
fprintf('%-8s %-8s %10s %10s\n','emitter','method','error','CEP50');
shown = [];
for i = 1:numel(res)
    r = res(i);
    if any(shown == r.ie) && isempty(r.sol), continue; end   % one line per emitter
    shown(end+1) = r.ie; %#ok<AGROW>
    if isempty(r.sol)
        fprintf('%-8s %-8s   no fix (%s)\n', names{r.ie}, 'none', r.info.reason);
    else
        fprintf('%-8s %-8s %8.0f m %8.0f m\n', names{r.ie}, r.info.method, r.err, r.sol.cep50);
    end
end
end

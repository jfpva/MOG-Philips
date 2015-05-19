function cardiac_phase = binCardiacPhases(Ncardiac,rtop,rr)
% cardiac_phase = binCardiacPhases(Ncardiac,rtop,rr)
% $Rev:: 196           $:  Revision of last commit
% $Author:: wvpotters  $:  Author of last commit
% $Date:: 2013-01-29 1#$:  Date of last commit
Ncardiac = double(Ncardiac);
    rtop = double(rtop);
      rr = double(rr);

relative_position_in_heartphase = rtop./rr;

bin_edges = linspace(0,max(relative_position_in_heartphase),Ncardiac+1);

cardiac_phase = zeros(size(rr));

for i = 1:Ncardiac
    cardiac_phase((relative_position_in_heartphase>=bin_edges(i) & relative_position_in_heartphase<bin_edges(i+1))) = i;
end
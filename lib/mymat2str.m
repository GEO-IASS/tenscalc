function str=mymat2str(mat)
% str=mymat2str(mat)
%   Converts a matrix to a string. Similar to mat2str, but faster and 
%   omits the brackets []. 
%
% Copyright 2012-2017 Joao Hespanha

% This file is part of Tencalc.
%
% TensCalc is free software: you can redistribute it and/or modify it
% under the terms of the GNU General Public License as published by the
% Free Software Foundation, either version 3 of the License, or (at your
% option) any later version.
%
% TensCalc is distributed in the hope that it will be useful, but
% WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
% General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with TensCalc.  If not, see <http://www.gnu.org/licenses/>.
    if isempty(mat)
        str='';
    else
        format=repmat('%.20g,',1,size(mat,2));
        format(end)=';';
        str=sprintf(format,mat');
        str(end)=[];
    end
end

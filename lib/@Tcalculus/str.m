function s=str(obj,tprod2mat,maxDepth)
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
    
    if nargin<2
        tprod2mat=false;
    end
    if nargin<3
        maxDepth=inf;
    end
    
    if tprod2mat
        obj=tprod_tprod2matlab(obj);
    end

    global TCsymbolicExpressions;

    %% determine which entries of TCsymbolicExpressions need to be printed
    [TCindex,depth]=children(obj,maxDepth);

    s='';
    %% print expression
    for i=1:length(TCindex)
        type=TCsymbolicExpressions(TCindex(i)).type;
        osize=TCsymbolicExpressions(TCindex(i)).osize;
        parameters=TCsymbolicExpressions(TCindex(i)).parameters;
        operands=TCsymbolicExpressions(TCindex(i)).operands;
        op_parameters=TCsymbolicExpressions(TCindex(i)).op_parameters;
        s=horzcat(s,repmat(' ',1,3*depth(i)),sprintf('%-12s= %s(',varname(TCindex(i)),type));
        if ~isempty(parameters)
            switch class(parameters)
              case 'char'
                s=horzcat(s,'''',parameters,''',');
              case 'double'
                s=horzcat(s,'[',index2str(parameters),'],');
              case 'struct'
                if isfield(parameters,'subs')
                    osize1=TCsymbolicExpressions(operands).osize;
                    for j=1:length(parameters.subs)
                        if isequal(parameters.subs{j}(:)',1:osize1(j))
                            s=horzcat(s,':,');
                        else
                            s=horzcat(s,'[',index2str(parameters.subs{j}(:)'),'],');
                        end
                    end
                elseif isfield(parameters,'typical_subscripts')
                    s=horzcat(s,'{with typical values},');
                else
                    parameters
                    error('unkown parameter type %s',class(parameters));
                end
              case 'cell'
                s=horzcat(s,char(parameters{1}),',');
              otherwise
                error('unkown parameter type %s',class(parameters));
            end
        end
        for i=1:length(operands)
            s=horzcat(s,sprintf('%s%d,',TCsymbolicExpressions(operands(i)).type,operands(i)));
            if ~isempty(op_parameters)
                s=horzcat(s,'[',index2str(op_parameters{i}),'],');
            end
        end
        s=horzcat(s,sprintf(') : [%s]\n',index2str(osize)));
    end
    s=horzcat(s,sprintf('%% created in %s\n',file_line(obj)));
end

function name=varname(TCindex)
    global TCsymbolicExpressions;
    name=sprintf('%s%d',TCsymbolicExpressions(TCindex).type,TCindex);
end

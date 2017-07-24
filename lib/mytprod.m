function M=mytprod(varargin)
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

    [tprod_size,sums_size]=checkTprodSizes(varargin{:});

    if 0
        fprintf('\n>>>tprod: ');
        for i=1:2:length(varargin)
            fprintf('[%s]/[%s], ',index2str(size(varargin{i})),index2str(varargin{i+1}));
        end
        fprintf('\n');
    end

    spa=false;
    for i=1:2:nargin
        if issparse(varargin{i}) && nnz(varargin{i})<.01*numel(varargin{i})
            spa=true;
            break
        end
    end
    if spa
        %tic
        M=mytprodSparse(tprod_size,varargin{:});
        %toc
        if 0
            MM=M;
        else
            return
        end
    end
    
    % create expanded matrices with dimension [tprod_size,sums_size]
    
    tic
    sizes=[tprod_size,sums_size];
    ind=[1:length(tprod_size),-1:-1:-length(sums_size)];
    msizes=sizes;
    while length(msizes)<2
        msizes=[msizes,1];
    end
    M=ones(msizes);
    big=numel(M)>5e6 && numel(M)>prod(tprod_size);
    if big
        fprintf('ATTENTION: tprod creates array with %5.1f million elements [size=%s]\n           eventually collapsed to  %5.1f million elements [size=%s] because of:\n           ', ...
                numel(M)/1e6,index2str(sizes),prod(tprod_size)/1e6,index2str(tprod_size));
        for i=1:2:length(varargin)
            fprintf('[%s]/[%s], ',index2str(size(varargin{i})),index2str(varargin{i+1}));
        end
        fprintf('\n');
    end
    for i=1:2:nargin
        if 0%issparse(varargin{i})
            fprintf('ATTENTION: tprod unsparsifying [%s] matrix with %d non-zero elements (%.3f%% fillin)\n',index2str(size(varargin{i})),nnz(varargin{i}),100*nnz(varargin{i})/numel(varargin{i}));
        end
        indi=varargin{i+1};
        missing=setdiff(ind,indi);
        order=[indi,missing];
        order(order<0)=length(tprod_size)-order(order<0);
        indi(indi<0)=length(tprod_size)-indi(indi<0);
        reps=msizes;
        reps(indi)=1;
        Mi=full(varargin{i});
        if length(order)>=2
            Mi=ipermute(Mi,order);
        end
        M=M.*repmat(Mi,reps);
    end
    for i=length(tprod_size)+1:length(ind)
        M=sum(M,i);
    end
    %toc
    if big
        fprintf('done!\n');
    end

    if 0 %spa
        disp('MM')
        size(MM)
        min(MM(:))
        max(MM(:))

        disp('M')
        size(M)
        min(M(:))
        max(M(:))

        disp(sumsqr(MM-M))
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%        mytprod() auxiliary functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [tprod_size,sums_size]=checkTprodSizes(varargin)
    
    tprod_size=[];
    sums_size=[];
    for i=1:2:nargin
        obj=varargin{i};
        ind=varargin{i+1};
        osize=size(obj);
        % remove singleton dimension at the end of column vectors
        if osize(2)==1 && length(ind)==1
            osize=osize(1);
        end
        % add singletons if needed
        if length(ind)>length(osize)
            osize=[osize,ones(length(ind)-length(osize),1)];
        end
        
        if length(ind)~=length(osize) && ~(isempty(ind) || isempty(osize))
            fprintf('tprod: term %d has size [%s] and index [%s]\n',...
                    (i+1)/2,index2str(osize),index2str(ind));
            error(['tprod requires each indice to have the same number of ' ...
                   'entries as the size of the corresponding object\n'])
        end

        for j=1:length(ind)
            if ind(j)>0
                if length(tprod_size)<ind(j)
                    % pad with nan
                    tprod_size(end+1:ind(j))=nan;
                end
                if length(tprod_size)>=ind(j) && tprod_size(ind(j))>0 ...
                        && tprod_size(ind(j))~=size(obj,j)
                    obj,tprod_size
                    error(['incompatible sizes found in object ' ...
                           '%d, dimension %d (%d~=%d)\n'],i,j, ...
                          tprod_size(ind(j)),size(obj,j)); 
                end
                tprod_size(ind(j))=size(obj,j);
            else
                if length(sums_size)<-ind(j)
                    % pad with nan
                    sums_size(end+1:-ind(j))=nan;
                end
                if length(sums_size)>=-ind(j) && sums_size(-ind(j))>0 ...
                        && sums_size(-ind(j))~=size(obj,j)
                    obj,sums_size
                    error(['incompatible sizes found in object ' ...
                           '%d, dimension %d (%d~=%d)\n'],i,j, ...
                          sums_size(-ind(j)),size(obj,j)); 
                end
                sums_size(-ind(j))=size(obj,j);
            end
        end
    end
    
    if any(isnan(tprod_size)) || any(isnan(sums_size)) 
        tprod_size,sums_size
        error('tprod has no size for some indices/summations\n',i)
    end
end


function Hess_=ipmPD_CS(code,f,u,lambda,nu,F,G,...
                        smallerNewtonMatrix,addEye2Hessian,skipAffine,...
                        useLDL,atomicFactorization,...
                        cmexfunction,allowSave,debugConvergence)
% See ../doc/ipm.tex for an explanation of the formulas used here
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

%profile on
    
 if smallerNewtonMatrix
        fprintf('\n  Starting ipmPD_CS symbolic computations (smallNewtonMatrix)...\n');
    else
        fprintf('\n  Starting ipmPD_CS symbolic computations (largeNewtonMatrix)...\n');
    end
    t1=clock();
    
    %% Define all sizes
    nU=length(u);
    nG=length(G);
    nF=length(F);

    fprintf('    getJ()...');
    t2=clock();
    declareGet(code,f,'getJ__');

    if debugConvergence
        declareGet(code,u,'getU__');
        if nG>0
            declareGet(code,{G,nu},'getGNu__');
        end
        if nF>0
            declareGet(code,{F,lambda},'getFLambda__');
        end
    end 
    
    fprintf('(%.2f sec)\n    1st derivates...',etime(clock(),t2));
    t2=clock();
    f_u=gradient(f,u);
    Lf=f;
    Lf_u=f_u;
    
    if nF>0
        mu=Tvariable('mu__',[]);
        %muOnes=mu*Tones(nF);
        muOnes=reshape(mu,1);
        muOnes=muOnes(ones(nF,1));
        
        declareSet(code,mu,'setMu__');
        
        F_u=gradient(F,u);
        gap=tprod(lambda,-1,F,-1);                    % gap=lambda*F;
        Lf=Lf-gap;                                    % Lf=Lf-gap;
        Lf_u=Lf_u-tprod(F_u,[-1,1],lambda,-1);        % Lf_u=Lf_u-F_u'*lambda;
        
        % Automatic initialization of lambda
        declareCopy(code,lambda,muOnes./F,'initDualIneq__');
        
        declareGet(code,{gap,min(F,1),min(lambda,1)},'getGapMinFMinLambda__');
    else
        F=Tzeros(0);
        F_u=Tzeros([0,nU]);
        gap=Tzeros([]);
        mu=Tzeros([]);
        muOnes=Tzeros(0);
    end

    if nG>0
        G_u=gradient(G,u);
        Lf=Lf+tprod(nu,-1,G,-1);                      % Lf=Lf+nu*G;
        Lf_u=Lf_u+tprod(G_u,[-1,1],nu,-1);            % Lf_u=Lf_u+G_u'*nu;

        % Automatic initialization of nu
        declareCopy(code,nu,Tones(nG),'initDualEq__');

        declareGet(code,norminf(G),'getNorminf_G__');
    else
        G=Tzeros(0);
        G_u=Tzeros([0,nU]);
    end
    
    declareGet(code,Lf_u,'getGrad__');
    declareGet(code,norminf(Lf_u),'getNorminf_Grad__');

    fprintf('(%.2f sec)\n    2nd derivatives...',etime(clock(),t2));
    t2=clock();

    Lf_uu=gradient(Lf_u,u);
    
    alpha=Tvariable('alpha__',[]);
    declareSet(code,alpha,'setAlpha__');

    if useLDL
        if atomicFactorization
            factor=@lu_sym;
        else
            factor=@ldl;
        end        
    else
        factor=@lu;
    end
    
    fprintf('(%.2f sec)\n    WW...',etime(clock(),t2));
    t2=clock();
    if smallerNewtonMatrix
        %%%%%%%%%%%%%%%%%%
        %% Small matrix %%
        %%%%%%%%%%%%%%%%%%

        LPG=tprod(lambda./F,1,F_u,[1,2]);
        Hess_=[Lf_uu+tprod(F_u,[-1,1],LPG,[-1,2],'associate'),G_u';
               G_u,Tzeros([nG,nG])];
        WW=  [Lf_uu+tprod(F_u,[-1,1],LPG,[-1,2],'associate')+tprod(addEye2Hessian,[],Teye(size(Lf_uu)),[1,2]),G_u';
              G_u,tprod(-addEye2Hessian,[],Teye([nG,nG]),[1,2])];
        muF=muOnes./F;         % muF=(mu*Tones(size(F)))./F;
        
        factor_ww=factor(WW,[cmexfunction,'_WW.subscripts'],[cmexfunction,'_WW.values']);
        if atomicFactorization
            factor_ww=declareAlias(code,factor_ww,'factor_ww',true);
        end
        
        if skipAffine
            b_s=[-f_u-tprod(G_u,[-1,1],nu,-1)+tprod(F_u,[-1,1],muF,-1);
                 -G];
        else
            %% affine direction
            b_a=[-f_u-tprod(G_u,[-1,1],nu,-1);
                 -G];
            
            dx_a=factor_ww\b_a;
            dx_a=declareAlias(code,dx_a,'dUNu_a__');
            
            dU_a=dx_a(1:nU);
            newU_a=u+alpha*dU_a;
            
            if nF>0
                dLambda_a=-LPG*dU_a-lambda;
                newLambda_a=lambda+alpha*dLambda_a;
                
                newF_a=substitute(F,u,newU_a);
                
                alphaPrimal_a=clp(F,F_u*dU_a);
                alphaDual_a=clp(lambda,dLambda_a);
                
                rho=tprod(newF_a,[-1],newLambda_a,[-1])./gap; % rho=(newF_a*newLambda_a)./gap;
                
                declareGet(code,{alphaPrimal_a,alphaDual_a},'getAlphas_a__');
                declareGet(code,min(newF_a,1),'getMinF_a__');
                declareGet(code,rho,'getRho__');
            else
                dLambda_a=Tzeros(nF);
            end
            % Mehrotra correction for search direction
            Mehrotra=(F_u*dU_a).*dLambda_a./F;
            b_s=[-f_u-tprod(G_u,[-1,1],nu,-1)+tprod(F_u,[-1,1],muF,-1)-tprod(F_u,[-1,1],Mehrotra,-1);
                 -G];
        end
        
        fprintf('(%.2f sec)\n    search directions...',etime(clock(),t2));
        t2=clock();
        %% search direction
        dx_s=factor_ww\b_s;
        dx_s=declareAlias(code,dx_s,'dx_s__');
        
        dU_s=dx_s(1:nU);
        newU_s=u+alpha*dU_s;
        dNu_s=dx_s(nU+1:end);
        newNu_s=nu+alpha*dNu_s;
        if nF>0
            if skipAffine
                dLambda_s=muF-LPG*dU_s-lambda;
            else
                dLambda_s=muF-LPG*dU_s-lambda-Mehrotra;
            end                
            newLambda_s=lambda+alpha*dLambda_s;
            
            alphaPrimal_s=clp(F,F_u*dU_s);
            alphaDual_s=clp(lambda,dLambda_s);
            declareGet(code,{alphaPrimal_s,alphaDual_s},'getAlphas_s__');
            
            newF_s=substitute(F,u,newU_s);
            declareGet(code,min(newF_s,1),'getMinF_s__');
            if debugConvergence
                declareGet(code,{newF_s,newLambda_s},'getFLambda_s__');
            end
        else
            newLambda_s=Tzeros(nF);
        end
        
        declareCopy(code,{u,nu,lambda},{newU_s,newNu_s,newLambda_s},'updatePrimalDual__');            
    else
        %%%%%%%%%%%%%%%%%%
        %% Large matrix %%
        %%%%%%%%%%%%%%%%%%

        Hess_=[Lf_uu,G_u',-F_u';
               G_u,Tzeros([nG,nG+nF]);
               -F_u,Tzeros([nF,nG]),-diag(F./lambda)];
        WW=[Lf_uu+tprod(addEye2Hessian,[],Teye(size(Lf_uu)),[1,2]),G_u',-F_u';
            G_u,-tprod(addEye2Hessian,[],Teye([nG,nG]),[1,2]),Tzeros([nG,nF]);
            -F_u,Tzeros([nF,nG]),-diag(F./lambda)-tprod(addEye2Hessian,[],Teye([nF,nF]),[1,2])];

        factor_ww=factor(WW,[cmexfunction,'_WW.subscripts'],[cmexfunction,'_WW.values']);
        if atomicFactorization
            factor_ww=declareAlias(code,factor_ww,'factor_ww',true);
        end

        if skipAffine
            b_s=[-Lf_u;
                 -G;
                 F-muOnes./lambda];
        else
            %% affine direction
            b_a=[-Lf_u;
                 -G;
                 F];
            
            dx_a=factor_ww\b_a;
            dx_a=declareAlias(code,dx_a,'dUNu_a__');
            
            dU_a=dx_a(1:nU);
            newU_a=u+alpha*dU_a;
            
            if nF>0
                dLambda_a=dx_a(nU+nG+1:nU+nG+nF);
                newLambda_a=lambda+alpha*dLambda_a;
                
                newF_a=substitute(F,u,newU_a);                
                alphaPrimal_a=clp(F,F_u*dU_a);
                alphaDual_a=clp(lambda,dLambda_a);
                
                rho=tprod(newF_a,[-1],newLambda_a,[-1])./gap; % rho=(newF_a*newLambda_a)./gap;
                
                declareGet(code,{alphaPrimal_a,alphaDual_a},'getAlphas_a__');
                
                declareGet(code,min(newF_a,1),'getMinF_a__');
                declareGet(code,rho,'getRho__');
            else
                dLambda_a=Tzeros(nF);
            end
            
            % Mehrotra correction for search direction
            b_s=[-Lf_u;
                 -G;
                 F+(F_u*dU_a).*dLambda_a./lambda-muOnes./lambda];
        end
        
        %% search direction
        dx_s=factor_ww\b_s;
        dx_s=declareAlias(code,dx_s,'dx_s__');
        
        dU_s=dx_s(1:nU);
        newU_s=u+alpha*dU_s;
        dNu_s=dx_s(nU+1:nU+nG);
        newNu_s=nu+alpha*dNu_s;

        if nF>0
            dLambda_s=dx_s(nU+nG+1:nU+nG+nF);
            newLambda_s=lambda+alpha*dLambda_s;
        
            alphaPrimal_s=clp(F,F_u*dU_s);
            alphaDual_s=clp(lambda,dLambda_s);
            declareGet(code,{alphaPrimal_s,alphaDual_s},'getAlphas_s__');
            newF_s=substitute(F,u,newU_s);
            declareGet(code,min(newF_s,1),'getMinF_s__');
            if debugConvergence
                declareGet(code,{newF_s,newLambda_s},'getFLambda_s__');
            end
        else
            newLambda_s=Tzeros(nF);
        end
        declareCopy(code,{u,nu,lambda},{newU_s,newNu_s,newLambda_s},'updatePrimalDual__');
    end % smallerNewtonMatrix
    
    % declareGet(code,full(WW),'getWW__');
    % declareGet(code,u,'getU__');
    % declareGet(code,lambda,'getLambda__');
    % declareGet(code,b_s,'getb_s__');
    % declareGet(code,dx_s,'getDx_s__');


    % declareSave after lu's to make sure previous "typical" values
    % are used by lu, prior to being overwritten by declareSave
    if allowSave
        declareSave(code,WW,'saveWW__',[cmexfunction,'_WW.subscripts'])
    end

    fprintf('(%.2f sec)\n    ',etime(clock(),t2));
    fprintf('  done ipmPD_CS symbolic computations (%.3f sec)\n',etime(clock(),t1));
    
    %profile off
    %profile viewer
    
end


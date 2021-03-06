function varargout=cmex2equilibriumLatentCS(varargin)	
% To get help, type cmex2equilibriumLatentCS('help')
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

    %% Function global help
    declareParameter(...
        'Help', {
            'Creates a set of cmex functions for computing a Nash equilibrium'
            'of the form'
            '%  P1objective(P1variables^*,P2variables^*,latentVariables^*,parameters) ='
            '%        = minimize    P1objective(P1variables,P2variables^*,latentVariables,parameters)'
            '%          w.r.t.      P1variables,latentVariables'
            '%          subject to  P1constraints(P1variables,P2variables^*,latentVariables,parameters)'
            '%                      latentConstraints(P1variables,P2variables^*,latentVariables,parameters)'
            '%  P2objective(P1variables^*,P2variables^*,latentVariables^*,parameters) ='
            '%        = minimize    P2objective(P1variables^*,P2variables,latentVariables,parameters)'
            '%          w.r.t.      P2variables,latentVariables'
            '%          subject to  P2constraints(P1variables^*,P2variables,latentVariables,parameters)'
            '%                      latentConstraints(P1variables^*,P2variables,latentVariables,parameters)'
            'and returns'
            '  outputExpressions(P1variables^*,P2variables^*,latentVariables^*,parameters)'
            'See ipm.pdf for details of the optimization engine.'
            ' '
            'The solver is accessed through several cmex functions that can be'
            'accessed directly or through a matlab class.'
            'See |ipm.pdf| for details of the optimization engine.';
                });

    %% Declare input parameters
    declareParameter(...
        'VariableName','classname',...
        'DefaultValue',getFromPedigree(),...
        'Description',{
            'Name of the class to be created.'
            'A matlab class will be created with this name plus a |.m| extension.';
            'The class will have the following methods:';
            '   * |obj=classname()| - creates class and loads the dynamic library';
            '                         containing the C code';
            '   * |delete(obj)|     - deletes the class and unload the dynamic library';
            '   * |setP_{parameter}(obj,value)|'
            '                   - sets the value of one of the parameters'
            '   * |setV_{variable}(obj,value)|'
            '                   - sets the value of one of the optimization variables'
            '   * |[status,iter,time]=solve(obj,mu0,int32(maxIter),int32(saveIter))|'
            'where'
            '   * |mu0|      - initial value for the barrier variable'
            '   * |maxIter|  - maximum number of Newton iterations'
            '   * |saveIter| - iteration # when to save the "hessian" matrix'
            '                  (for subsequent pivoting/permutations/scaling optimization)'
            '                  only saves when |allowSave| is true.';
            ' '
            '                  When |saveIter=0|, the hessian matrix is saved'
            '                                     at the last iteration; and'
            '                  when |saveIter<0|, the hessian matrix is not saved.';
            ' '
            '                  The "hessian" matrix will be saved regardless of the';
            '                  value of |saveIter|, when the solver exists with |status=-2|'
            '   * |status|   - solver exist status';
            '                 *  0  = success';
            '                 *  >0 = solver terminated unexpectedly';
            '                 a nonzero status indicates the reason for termination';
            '                 in a binary format:'
            '                   bit  0 = 1 - (primal) variables violate constraints'
            '                   bit  1 = 1 - dual variables are negative'
            '                   bit  2 = 1 - failed to invert hessian'
            '                   bit  3 = 1 - maximum # of iterations reached';
            '                 when the solver exists because the maximum # of iterations'
            '                 was reached (bit 3 = 1), the remaining bits provide'
            '                 information about the solution returned';
            '                   bit  4 = 1 - gradient larger then |gradTolerance|'
            '                   bit  5 = 1 - equality constraints violate |equalTolerance|';
            '                   bit  6 = 1 - duality gap larger than |desiredDualityGap|';
            '                   bit  7 = 1 - barrier variable larger than minimum value';
            '                   bit  8 = 1 - scalar gain |alpha| in Newton direction';
            '                                smaller than alphaMin'
            '                   bit  9 = 1 - scalar gain |alpha| in Newton direction';
            '                                smaller than .1'
            '                   bit 10 = 1 - scalar gain |alpha| in Newton direction';
            '                                smaller than .5'
            '   * |iter|    - number of iterations'
            '   * |time|    - solver''s compute time (in secs).'
            ' '
            'One can look "inside" this class to find the name of the cmex functions.'
                      });

    declareParameter(...
        'VariableName','folder',...
        'DefaultValue','.',...
        'Description', {
            'Path to the folder where the class and cmex files will be created.';
            'The folder will be created if it does not exist and it will be added';
            'to the begining of the path if not there already.'
                       });
    
    declareParameter(...
        'VariableName','P1objective',...
        'Description',{
            'Scalar Tcalculus symbolic object to be optimized for player 1.'
                      });
    declareParameter(...
        'VariableName','P1optimizationVariables',...
        'Description',{
            'Cell-array of Tcalculus symbolic objects representing the'
            'variables to be optimized by player 1.'
                      });
    declareParameter(...
        'VariableName','P1constraints',...
        'DefaultValue',{},...
        'Description',{
            'Cell-array of Tcalculus symbolic objects representing the'
            'constraints for player 1. Both equality and inequality'
            'constraints are allowed.'
                      });

    declareParameter(...
        'VariableName','P2objective',...
        'Description',{
            'Scalar Tcalculus symbolic object to be optimized for player 2.'
                      });
    declareParameter(...
        'VariableName','P2optimizationVariables',...
        'Description',{
            'Cell-array of Tcalculus symbolic objects representing the'
            'variables to be optimized by player 2.'
                      });
    declareParameter(...
        'VariableName','P2constraints',...
        'DefaultValue',{},...
        'Description',{
            'Cell-array of Tcalculus symbolic objects representing the'
            'constraints for player 2. Both equality and inequality'
            'constraints are acceptable.'
                      });

    declareParameter(...
        'VariableName','latentVariables',...
        'DefaultValue',{},...
        'Description',{
            'Cell-array of Tcalculus symbolic objects representing the'
            'common latent variables.'
                      });
    declareParameter(...
        'VariableName','latentConstraints',...
        'DefaultValue',{},...
        'Description',{
            'Cell-array of Tcalculus symbolic objects representing the'
            'constraints that define the latent variables.'
            'Only equality constraints are acceptable.'
                      });

    declareParameter(...
        'VariableName','parameters',...
        'DefaultValue',{},...
        'Description',{
            'Cell-array of Tcalculus symbolic objects representing the '
            'parameters (must be given, not optimized).'
                      });

    declareParameter(...
        'VariableName','outputExpressions',...
        'Description',{
            'Cell-array of Tcalculus symbolic objects representing the '
            'variables to be returned.'
                      });

    declareParameter(...
        'VariableName','method',...
        'DefaultValue','primalDual',...
        'AdmissibleValues',{'primalDual'},...
        'Description',{
            'Variable that specifies which method should be used:'
            '* |primalDual| - interior point primal-dual method'
            '* |barrier|    - interior point barrier method'
            '                   (not yet implemented)'
                      });

    declareParameter(...
        'VariableName','alphaMin',...
        'DefaultValue',1e-5,...
        'Description',{
            'Minimum value for the scalar gain in the line search'
            'below which a search direction is declared to have failed.'
                      });

    declareParameter(...
        'VariableName','alphaMax',...
        'DefaultValue',1,...
        'Description',{
            'Maximum value for the scalar gain in the line search.'
            'Should only be set lower to 1 for very poorly scaled problems.'
                      });

    declareParameter(...
        'VariableName','skipAffine',...
        'DefaultValue',false,...
        'AdmissibleValues',{false,true},...
        'Description',{
            'When |true| the affine search direction step is omitted.'
                      });

    declareParameter(...
        'VariableName','umfpack',...
        'DefaultValue',false,...
        'AdmissibleValues',{false,true},...
        'Description',{
            'When |true| system of linear equations needed for the Newton step';
            'is solved using the umfpack package.'
                      });
    
    declareParameter(...
        'VariableName','smallerNewtonMatrix',...
        'DefaultValue',false,...
        'AdmissibleValues',{false,true},...
        'Description',{
            'When |true| the matrix that needs to be inverted to compute a Newton step'
            'is reduced by first eliminating the dual variables associated with inequality'
            'constrainst.'
            'However, often the smaller matrix is not as sparse so the computation'
            'may actually increase.'
                      });
    
    declareParameter(...
        'VariableName','delta',...
        'DefaultValue',3,...
        'AdmissibleValues',{2,3},...
        'Description',{
            'Delta parameter used to determine mu based on the affine direction.'
            'Set |Delta=3| for well behaved problems (for an aggressive convergence)'
            'and |Delta=2| in poorly conditioned problems (for a more robust behavior).'
            'This parameter is only used when |skipAffine=false|.'
                      });
    declareParameter(...
        'VariableName','muFactorAggressive',...
        'DefaultValue',1/3,...
        'Description',{
            'Multiplicative factor used to update the barrier parameter'
            '(must be smaller than 1).'
            'This value is used when there is good progress along the'
            'Newton direction.'
            'Nice convex problems can take as low as 1/100, but '
            'poorly conditioned problems may require as high as 1/3.'
            'This parameter is only used when |skipAffine=true|.'
                      });
    declareParameter(...
        'VariableName','muFactorConservative',...
        'DefaultValue',.75,...
        'Description',{
            'Multiplicative factor used to update the barrier parameter'
            '(must be smaller than 1).'
            'This value is used when there is poor or no progress along the'
            'Newton direction. A value not much smaller than one is preferable.'
                      });

    declareParameter(...
        'VariableName','gradTolerance',...
        'DefaultValue',1e-4,...
        'Description',{
            'Maximum norm for the gradient below which the first order optimality'
            'conditions assumed to by met.'
                      });

    declareParameter(...
        'VariableName','equalTolerance',...
        'DefaultValue',1e-4,...
        'Description',{
            'Maximum norm for the vector of equality constraints below which the'
            'equalities are assumed to hold.'
                      });

    declareParameter(...
        'VariableName','desiredDualityGap',...
        'DefaultValue',1e-5,...
        'Description',{
            'Value for the duality gap that triggers the end of'
            'the constrained optimization. The overall optimization '
            'terminates at the end of the first Newton step for which'
            'the duality gap becomes smaller than this value.'
                      });
    
    declareParameter(...
        'VariableName','maxIter',...
        'DefaultValue',200,...
        'Description',{
            'Maximum number of Newton iterations.'
                      });

    declareParameter(...
        'VariableName','addEye2Hessian',...
        'DefaultValue',0*1e-6,...
        'Description',{
            'Add to the Hessian matrix appropriate identity matrices scaled by this constant.'
            '[Should be avoided since does not seem to have a good justification for Nash'
            'equilibria.]'
                      });
    
    declareParameter(...
        'VariableName','scratchbookType',...
        'DefaultValue','double',...
        'AdmissibleValues',{'double','float'},...
        'Description',{
            'C variable type used for the scratchbook. ';
            'See csparse documentation.'
                      });
    
    declareParameter(...
        'VariableName','fastRedundancyCheck',...
        'DefaultValue',false,...
        'AdmissibleValues',{false,true},...
        'Description',{
            'when true, very intensive operations (like the lu factorization) '
            'do not check if it is possible to reuse computations.'
            'See csparse documentation.'
                      });
    
    declareParameter(...
        'VariableName','codeType',...
        'DefaultValue','C',...
        'AdmissibleValues',{'C','C+asmSB','C+asmLB'},...
        'Description',{
            'Type of code produced:'
            '* |C| - all computations done in pure C code. Ideal for final code.'
            '          '
            '          Impact on non-optimized compilation:'
            '            * medium compilation times'
            '            * largest code size'
            '            * slowest run times';
            '          '
            '          Impact on optimized code:'
            '            Gives the most freedom to the compiler for optimization'
            '            * slowest compile optimization times'
            '            * fastest run times'
            '            * smallest code sizes';
            '          '
            '* |C+asmLB| - little C code, with most of the computations done'
            '          by large blocks of inlined assembly code. Ideal for testing.'
            '          '
            '          Impact on non-optimized compilation:'
            '            * fastest compilation times'
            '            * smallest code size'
            '            * fastest run times (for non-optimized code)'
            '          '
            '          Impact on optimized compilation:'
            '            Most of the compiler optimization is restricted to re-ordering'
            '            and/or inlining the large blocks of asm code'
            '            * fastest compile optimization times'
            '            * slowest run times'
            '            * largest optimized code sizes (due to inlining large blocks)';
            '          '
            '          NOT FULLY IMPLEMENTED.';
            '          '
            '* |C+asmSB| - little C code, with most of the computations done'
            '          by small blocks of inlined assembly code'
            '          '
            '          Impact on non-optimized compilation:'
            '            * medium compilation times'
            '            * medium code size'
            '            * medium run times'
            '          '
            '          Impact on optimized code:'
            '            Most of the compiler optimization is restricted to re-ordering'
            '            and/or inlining the small blocks of asm code'
            '            * medium compile optimization times,'
            '            * medium run times'
            '            * medium code sizes';
            '          '
            '          NOT FULLY IMPLEMENTED NOR TESTED.'
                      });

    declareParameter(...
        'VariableName','compilerOptimization',...
        'DefaultValue','-O1',...
        'AdmissibleValues',{'-O0','-O1','-O2','-O3','-Ofast'},...
        'Description',{
            'Optimization parameters passed to the C compiler.'
            '* |-O1| often generates the fastest code, whereas'
            '* |-O0| compiles the fastest'
            'Only used when either |compileGateways|, |compileLibrary|, or '
            '|compileStandalones| are set to |true|.'
        });

    declareParameter(...
        'VariableName','callType',...
        'DefaultValue','dynamicLibrary',...
        'AdmissibleValues',{'dynamicLibrary','client-server'},...
        'Description', {
            'Method used to interact with the solver:';
            '* |dynamicLibrary| - the solver is linked with matlab using a dynamic library';
            '* |client-server|   - the solver runs as a server in independent process,';
            '                     and a socket is used to exchange data.'
                       });

    declareParameter(...
        'VariableName','absolutePath',...
        'DefaultValue',true,...
        'AdmissibleValues',{true,false},...
        'Description', {
            'When ''true'' the the cmex functions use an absolute path to open';
            'the dynamic library, which means that the dynamic library cannot';
            'be moved away from the folder where it was created.';
            ' '
            'When ''false'' no path information about the dynamic library is'
            'included in the cmex function, which must then rely on the OS-specific';
            'method used to find dynamic libraries. See documentation of ''dlopen'''
            'for linux and OSX or ''LoadLibrary'' for Microsoft Windows.'
            ' '
            'This parameter is used only when ''callType''=''dynamicLibrary''.'
                       });
    
    declareParameter(...
        'VariableName','serverProgramName',...
        'DefaultValue','',...
        'Description', {
            'Name of the executable file for the server executable.'
            'This parameter is used only when |callType=''client-server''|.'
                       });
    
    declareParameter(...
        'VariableName','serverAddress',...
        'DefaultValue','localhost',...
        'Description', {
            'IP address (or name) of the server.'
            'This parameter is used only when |callType=''client-server''|.'
                       });
    
    declareParameter(...
        'VariableName','port',...
        'DefaultValue',1968,...
        'Description', {
            'Port number for the socket that connects client and server.'
            'This parameter is used only when |callType=''client-server''|.'
                       });

    declareParameter(...
        'VariableName','compileGateways',...
        'DefaultValue',true,...
        'AdmissibleValues',{true,false},...
        'Description', {
            'When |true| the gateway functions are compiled using |cmex|.'
                       });
    
    declareParameter(...
        'VariableName','compileLibrary',...
        'DefaultValue',true,...
        'AdmissibleValues',{true,false},...
        'Description', {
            'When |true| the dynamicLibrary is compiled using |gcc|.'
            'This parameter is used only when |callType=''dynamicLibrary''|.'
                       });
    
    declareParameter(...
        'VariableName','compileStandalones',...
        'DefaultValue',true,...
        'AdmissibleValues',{true,false},...
        'Description', {
            'When |true| the standalone/server executable is compiled using |gcc|.'
            'This parameter is used only when |callType| has one of the values:';
            '   |''standalone''| or |''client-server''|'
                       });
    
    declareParameter(...
        'VariableName','targetComputer',...
        'DefaultValue',lower(computer),...
        'AdmissibleValues',{'maci64','glnxa64','pcwin64'},...
        'Description', {
            'OS where the C files will be compiled.'
                       });
    
    declareParameter(...
        'VariableName','serverComputer',...
        'DefaultValue',lower(computer),...
        'AdmissibleValues',{'maci64','glnxa64','pcwin64'},...
        'Description', {
            'OS where the server will be compiled.'
            'This parameter is used only when |callType=''client-server''|.'
                       });

    declareParameter(...
        'VariableName','solverVerboseLevel',...
        'DefaultValue',2,...
        'Description',{
            'Level of verbose for the solver outputs:';
            '* 0  - the solver does not produce any output and does not report timing information';
            '* 1  - the solver does not produce any output but reports timing information';
            '* 2  - the solver only report a summary of the solution status'
            '       when the optimization terminates';
            '* 3  - the solver reports a summary of the solution status '
            '       at each iteration';
            '* >3 - the solver produces several (somewhat unreadable) outputs'
            '       at each iteration step'
                      });
    
    declareParameter(...
        'VariableName','debugConvergence',...
        'DefaultValue',false,...
        'AdmissibleValues',{true,false},...
        'Description',{
            'Includes additional output to help debug failed convergence.'
                      });
    
    declareParameter(...
        'VariableName','debugConvergenceThreshold',...
        'DefaultValue',1e5,...
        'Description',{
            'Threshold above which solver warns about large values.';
            'Only used when |debugConvergence=true|';
                      });
    
    declareParameter(...
        'VariableName','allowSave',...
        'DefaultValue',false,...
        'AdmissibleValues',{true,false},...
        'Description',{
            'Generates code that permit saving the "hessian" matrix, for subsequent'
            'optimization of pivoting, row/column permutations, and scaling'
            'for the hessian''s LU factorization.'
            'The hessian in saved in two files named'
            '%   |{classname}_WW.subscripts| and |{classname}_WW.values|'
            'that store the sparsity structure and the actual values, respectively,'
            'at some desired iteration (see output parameter |solver|).'
                      });

    declareParameter(...
        'VariableName','profiling',...
        'DefaultValue',false,...
        'AdmissibleValues',{true,false},...
        'Description',{
            'When nonzero, adds profiling to the C code.'
            ' '
            'Accumulated profiling information is diplayed on the screen when the'
            'dynamic library is unloaded.'
                      });
    
    %% Output parameters
    declareOutput(...
        'VariableName','classname',...
        'Description', {
            'Name of the class created.'
                       });

    declareOutput(...
        'VariableName','code',...
        'Description', {
            'csparse object with the code generated.'
                       });

    if 0
        declareOutput(...
            'VariableName','debugInfo',...
            'Description',{
                'Data to be passed to debugConvergenceAnalysis.'
                          });
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% Retrieve parameters and inputs
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    [stopNow,params]=setParameters(nargout,varargin);
    if stopNow
        return 
    end

    %% transfer any folder in classname into folder
    [folder,classname]=fileparts(fsfullfile(folder,classname));

    %% create folder if it does not exist
    if ~strcmp(folder,'.') && ~exist(folder,'dir')
        fprintf('cmex2equilibriumLatentCS: outputs folder ''%s'' does not exist, creating it\n',folder);
        if mkdir(folder)==0
            error('Unable to create folder ''%s''\n',folder)
        end
    end
    
    rmpath(folder);
    addpath(folder);
    
    %% Fix class when gotten from pedigree
    classname=regexprep(classname,'+TS=','_TS_');
    classname=regexprep(classname,'-','_');
    classname=regexprep(classname,'+','_');

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% Check input parameters
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    if ~iscell(parameters)
        parameters
        error('parameters must be a cell array of Tcalculus variables');
    end

    for i=1:length(parameters)
        if ~isequal(type(parameters{i}),'variable')
            parameters{i}
            error('%dth parameter must be of the type ''variable'' (not [%s])\n',...
                  i,type(parameters{i}));
        end
    end

    if ~iscell(P1optimizationVariables)
        P1optimizationVariables
        error('P1optimizationVariables must be a cell array of Tcalculus variables');
    end

    for i=1:length(P1optimizationVariables)
        if ~isequal(type(P1optimizationVariables{i}),'variable')
            P1optimizationVariables{i}
            error('%dth P1optimizationVariables must be of the type ''variable'' (not [%s])\n',...
                  i,type(P1optimizationVariables{i}));
        end
    end

    if ~iscell(P2optimizationVariables)
        P2optimizationVariables
        error('P2optimizationVariables must be a cell array of Tcalculus variables');
    end

    for i=1:length(P2optimizationVariables)
        if ~isequal(type(P2optimizationVariables{i}),'variable')
            P2optimizationVariables{i}
            error('%dth P2optimizationVariables must be of the type ''variable'' (not [%s])\n',...
                  i,type(P2optimizationVariables{i}));
        end
    end

    if ~isempty(size(P1objective))
        error('P1''s minimization criterion must be scalar (not [%s])',...
              index2str(size(P1objective)));
    end

    if ~isempty(size(P2objective))
        error('P2''s minimization criterion must be scalar (not [%s])',...
              index2str(size(P2objective)));
    end

    if ~isempty(P1constraints) && ~iscell(P1constraints)
        error('P1''s constraints parameter must be a cell array\n');
    end

    if ~isempty(P2constraints) && ~iscell(P2constraints)
        error('P2''s constraints parameter must be a cell array\n');
    end

    if ~iscell(latentVariables)
        latentVariables
        error('latentOptimizationVariables must be a cell array of Tcalculus variables');
    end

    if ~isempty(latentConstraints) && ~iscell(latentConstraints)
        error('latent constraints parameter must be a cell array\n');
    end

    fprintf('cmex2equilibriumLatentCS: ...');
    t_cmexCS=clock();
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% Declare the problem-specific variables 
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    t_csparse=clock();
    debug=false;
    tprod2matlab=false;
    %code=csparse0(scratchbookType,debug);   % using fastTable.m
    %code=csparse1(scratchbookType,debug);  % using fastTable.m, string I_ instruction types
    %code=csparse2(scratchbookType,debug);  % using fastTable.m, integer instruction types
    code=csparse(scratchbookType,debug,tprod2matlab,fastRedundancyCheck); % using instructionsTable.c
    classhelp={'% Create object';
               sprintf('obj=%s();',classname)};
    
    % template for createGateway
    template=struct('MEXfunction',{},...% string
                    'Cfunction',{},...  % string
                    'method',{},...     % string
                    'inputs',struct(...  
                        'type',{},...   % string
                        'name',{},...   % cell-array of strings (one per dimension)
                        'sizes',{}),... % cell-array of strings (one per dimension)
                    'outputs',struct(... % string
                        'type',{},...   % string
                        'name',{},...   % cell-array of strings (one per dimension)
                        'sizes',{}),... % cell-array of strings (one per dimension)
                    'preprocess',{},... % strings (starting with parameters in parenthesis)'
                    'includes',{});     % cell-array of strings (one per file)
    %% Declare 'sets' for initializing parameters
    if length(parameters)>0
        classhelp{end+1}='% Set parameters';
    end
    for i=1:length(parameters)
        template(end+1,1).MEXfunction=sprintf('%s_set_%s',classname,name(parameters{i}));
        template(end).Cfunction=sprintf('%s_set_%s',classname,name(parameters{i}));
        template(end).method=sprintf('setP_%s',name(parameters{i}));
        template(end).inputs =struct('type','double',...
                                     'name',name(parameters{i}),...
                                     'sizes',size(parameters{i}));
        declareSet(code,parameters{i},template(end).MEXfunction);
        msize=size(parameters{i});while(length(msize)<2),msize(end+1)=1;end
        classhelp{end+1}=sprintf('setP_%s(obj,{[%s] matrix});',...
                                name(parameters{i}),index2str(msize));
    end

    %% Declare 'sets' for initializing primal variables
    classhelp{end+1}='% Initialize primal variables';
    % Player 1
    for i=1:length(P1optimizationVariables)
        template(end+1,1).MEXfunction=sprintf('%s_set_%s',...
                                            classname,name(P1optimizationVariables{i}));
        template(end).Cfunction=sprintf('%s_set_%s',classname,name(P1optimizationVariables{i}));
        template(end).method=sprintf('setV_%s',name(P1optimizationVariables{i}));
        template(end).inputs =struct('type','double',...
                                     'name',name(P1optimizationVariables{i}),...
                                     'sizes',size(P1optimizationVariables{i}));
        declareSet(code,P1optimizationVariables{i},template(end).MEXfunction);
        msize=size(P1optimizationVariables{i});while(length(msize)<2),msize(end+1)=1;end
        classhelp{end+1}=sprintf('setV_%s(obj,{[%s] matrix});',...
                                 name(P1optimizationVariables{i}),index2str(msize));
    end
    % Player 2
    for i=1:length(P2optimizationVariables)
        template(end+1,1).MEXfunction=sprintf('%s_set_%s',...
                                            classname,name(P2optimizationVariables{i}));
        template(end).Cfunction=sprintf('%s_set_%s',classname,name(P2optimizationVariables{i}));
        template(end).method=sprintf('setV_%s',name(P2optimizationVariables{i}));
        template(end).inputs =struct('type','double',...
                                     'name',name(P2optimizationVariables{i}),...
                                     'sizes',size(P2optimizationVariables{i}));
        declareSet(code,P2optimizationVariables{i},template(end).MEXfunction);
        msize=size(P2optimizationVariables{i});while(length(msize)<2),msize(end+1)=1;end
        classhelp{end+1}=sprintf('setV_%s(obj,{[%s] matrix});',...
                                 name(P2optimizationVariables{i}),index2str(msize));
    end
    % Latent variables
    for i=1:length(latentVariables)
        template(end+1,1).MEXfunction=sprintf('%s_set_%s',classname,name(latentVariables{i}));
        template(end).Cfunction=sprintf('%s_set_%s',classname,name(latentVariables{i}));
        template(end).method=sprintf('setV_%s',name(latentVariables{i}));
        template(end).inputs =struct('type','double',...
                                     'name',name(latentVariables{i}),...
                                     'sizes',size(latentVariables{i}));
        declareSet(code,latentVariables{i},template(end).MEXfunction);
        msize=size(latentVariables{i});while(length(msize)<2),msize(end+1)=1;end
        classhelp{end+1}=sprintf('setV_%s(obj,{[%s] matrix});',...
                                 name(latentVariables{i}),index2str(msize));
    end
    
    %% Define constraints, dual variables, and declare 'sets' for initializing dual variables

    if verboseLevel>1
        fprintf('Defining constraints and dual variables... ');
    end

    % Player 1
    [Gu,Fu,P1nus,P1lambdas,outputExpressions,tpl]=...
        parseConstraints(code,classname,P1constraints,outputExpressions,'P1');
    template=[template;tpl];    
    
    
    % Player 2
    [Gd,Fd,P2nus,P2lambdas,outputExpressions,tpl]=...
        parseConstraints(code,classname,P2constraints,outputExpressions,'P2');
    template=[template;tpl];    

    % Latent constraints (only one H, but two sets of dual variables)
    [H,~,P1xnus,err,outputExpressions,tpl]=...
        parseConstraints(code,classname,latentConstraints,outputExpressions,'P1x');
    template=[template;tpl];    
    [H,~,P2xnus,err,outputExpressions,tpl]=...
        parseConstraints(code,classname,latentConstraints,outputExpressions,'P2x');
    template=[template;tpl];    

    if ~isempty(err)
        latentConstraints
        error('latent constraints cannot be inequalities\n');
    end
        
    %% Pack constraints

    if verboseLevel>1
        fprintf('Packing expressions and variables... ');
    end

    %% Pack primal variables
    % Player 1
    [u,packU,unpackU,P1objective,P2objective,outputExpressions,Fu,Gu,Fd,Gd,H]...
        =packVariables(P1optimizationVariables,'u_',...
                       P1objective,P2objective,outputExpressions,Fu,Gu,Fd,Gd,H);
    u0=packExpressions(P1optimizationVariables);
    % Player 2
    [d,packD,unpackD,P1objective,P2objective,outputExpressions,Fu,Gu,Fd,Gd,H]...
        =packVariables(P2optimizationVariables,'d_',...
                       P1objective,P2objective,outputExpressions,Fu,Gu,Fd,Gd,H);
    d0=packExpressions(P2optimizationVariables);
    src={u0,d0};
    dst={u,d};
    % Latent
    if ~isempty(latentVariables)
        [x,packX,unpackX,P1objective,P2objective,outputExpressions,Fu,Gu,Fd,Gd,H]...
            =packVariables(latentVariables,'x_',...
                           P1objective,P2objective,outputExpressions,Fu,Gu,Fd,Gd,H);
        x0=packExpressions(latentVariables);
        src{end+1}=x0;
        dst{end+1}=x;
    else
        x=Tzeros(0);
    end
    
    if length(H)~=length(x)
        error('number of latent variables (=%d) must match number of latent (equality) constraints (=%d) so that latent variables are uniquely defined',length(x),length(H));
    end
    
    declareCopy(code,dst,src,'initPrimal__');

    %% Pack dual variables
    % Player 1
    if size(Gu,1)>0
        P1nu=packVariables(P1nus,'P1nu_');
        P1nu0=packExpressions(P1nus);
        src{end+1}=P1nu0;
        dst{end+1}=P1nu;
    else
        P1nu=Tzeros(0);
    end
    if size(Fu,1)>0
        P1lambda=packVariables(P1lambdas,'P1lambda_');
        P1lambda0=packExpressions(P1lambdas);
        src{end+1}=P1lambda0;
        dst{end+1}=P1lambda;
    else
        P1lambda=Tzeros(0);
    end
    % Player 2
    if size(Gd,1)>0
        P2nu=packVariables(P2nus,'P2nu_');
        P2nu0=packExpressions(P2nus);
        src{end+1}=P2nu0;
        dst{end+1}=P2nu;
    else
        P2nu=Tzeros(0);
    end
    if size(Fu,1)>0
        P2lambda=packVariables(P2lambdas,'P2lambda_');
        P2lambda0=packExpressions(P2lambdas);
        src{end+1}=P2lambda0;
        dst{end+1}=P2lambda;
    else
        P2lambda=Tzeros(0);
    end
    if size(H,1)>0
        P1xnu=packVariables(P1xnus,'P1xnu_');
        P2xnu=packVariables(P2xnus,'P2xnu_');
        P1xnu0=packExpressions(P1xnus);
        P2xnu0=packExpressions(P2xnus);
        src{end+1}=P1xnu0;
        dst{end+1}=P1xnu;
        src{end+1}=P2xnu0;
        dst{end+1}=P2xnu;
    else
        P1xnu=Tzeros(0);
        P2xnu=Tzeros(0);
    end
    declareCopy(code,dst,src,'initPrimalDual__');

    %% Generate the code for the functions that do the raw computation
    t_ipmPD=clock();
    ipmPDeqlat_CS(code,P1objective,P2objective,u,d,x,P1lambda,P1nu,P1xnu,P2lambda,P2nu,P2xnu,...
                  Fu,Gu,Fd,Gd,H,...
                  smallerNewtonMatrix,addEye2Hessian,skipAffine,...
                  umfpack,...
                  classname,allowSave,debugConvergence,profiling);
    code.statistics.time.ipmPD=etime(clock,t_ipmPD);
    
    %% Declare ipm solver 
    nZ=size(u,1)+size(d,1)+size(x,1);
    nG=size(Gu,1)+size(Gd,1)+size(H,1);
    nF=size(Fu,1)+size(Fd,1);
    nNu=size(Gu,1)+size(Gd,1)+2*size(H,1);

    classhelp{end+1}='% Solve optimization';
    classhelp{end+1}='[status,iter,time]=solve(obj,mu0,int32(maxIter),int32(saveIter));';
    template(end+1,1).MEXfunction=sprintf('%s_solve',classname);
    template(end).Cfunction='ipmPDeq_CSsolver';
    template(end).method='solve';
    template(end).inputs(1) =struct('type','double','name','mu0','sizes',1);
    template(end).inputs(2) =struct('type','int32','name','maxIter','sizes',1);
    template(end).inputs(3) =struct('type','int32','name','saveIter','sizes',1);
    template(end).outputs(1)=struct('type','int32','name','status','sizes',1);
    template(end).outputs(2)=struct('type','int32','name','iter','sizes',1);
    template(end).outputs(3)=struct('type','double','name','time','sizes',1);
    template(end).outputs(4)=struct('type','double','name','z','sizes',[nZ,maxIter+1]);
    template(end).outputs(5)=struct('type','double','name','nu','sizes',[nNu,maxIter+1]);
    template(end).outputs(6)=struct('type','double','name','lambda','sizes',[nF,maxIter+1]);
    template(end).outputs(7)=struct('type','double','name','dZ_s','sizes',[nZ,maxIter]);
    template(end).outputs(8)=struct('type','double','name','dNu_s','sizes',[nNu,maxIter]);
    template(end).outputs(9)=struct('type','double','name','dLambda_s','sizes',[nF,maxIter]);
    template(end).outputs(10)=struct('type','double','name','G','sizes',[nG,maxIter+1]);
    template(end).outputs(11)=struct('type','double','name','F','sizes',[nF,maxIter+1]);
    template(end).outputs(12)=struct('type','double','name','primaAlpha_s','sizes',[maxIter+1]);
    template(end).outputs(13)=struct('type','double','name','dualAlpha_s','sizes',[maxIter+1]);
    template(end).outputs(14)=struct('type','double','name','finalAlpha','sizes',[maxIter+1]);

    %folder='.';
    classFolder=fsfullfile(folder,sprintf('@%s',classname));
    if ~exist(classFolder,'dir')
        fprintf('class classFolder @%s does not exist, creating it... ',classname);
        mkdir(classFolder);
    end
    
    defines.saveNamePrefix=['"',fsfullfile(classFolder,classname),'"'];
    defines.nZ=size(u,1)+size(d,1)+size(x,1);
    defines.nU=size(u,1);
    defines.nD=size(d,1);
    defines.nX=size(x,1);
    defines.nG=size(Gu,1)+size(Gd,1)+size(H,1);
    defines.nF=size(Fu,1)+size(Fd,1);
    defines.nNu=size(Gu,1)+size(Gd,1)+2*size(H,1);
    defines.gradTolerance=sprintf('%e',gradTolerance); % to make double
    defines.equalTolerance=sprintf('%e',equalTolerance); % to make double
    defines.desiredDualityGap=sprintf('%e',desiredDualityGap); % to make double
    defines.alphaMin=sprintf('%e',alphaMin); % to make double
    defines.alphaMax=sprintf('%e',alphaMax); % to make double
    defines.muFactorAggressive=sprintf('%e',muFactorAggressive); % to make double
    defines.muFactorConservative=sprintf('%e',muFactorConservative); % to make double
    defines.delta=delta;
    defines.skipAffine=double(skipAffine);
    defines.allowSave=double(allowSave);
    defines.debugConvergence=double(debugConvergence);
    defines.debugConvergenceThreshold=debugConvergenceThreshold;
    defines.profiling=double(profiling);
    defines.verboseLevel=solverVerboseLevel;
    
    pth=fileparts(which('cmex2equilibriumLatentCS.m'));
    declareFunction(code,fsfullfile(pth,'ipmPDeq_CSsolver.c'),'ipmPDeq_CSsolver',...
                    defines,template(end).inputs,template(end).outputs);
    
    %% Declare 'gets' for output expressions
    classhelp{end+1}='% Get outputs';
    classhelp{end+1}='';
    template(end+1,1).MEXfunction=sprintf('%s_getOutputs',classname);
    template(end).Cfunction=sprintf('%s_getOutputs',classname);
    template(end).method='getOutputs';
    template(end).outputs=struct('type',{},'name',{},'sizes',{});
    for i=1:length(outputExpressions)
        template(end).outputs(i).type='double';
        template(end).outputs(i).name=sprintf('y%d',i);
        template(end).outputs(i).sizes=size(outputExpressions{i});
        classhelp{end}=sprintf('%sy%d,',classhelp{end},i);
    end
    classhelp{end}=sprintf('[%s]=getOutputs(obj);',classhelp{end}(1:end-1));
    declareGet(code,outputExpressions,template(end).MEXfunction);

    code.statistics.time.csparse=etime(clock,t_csparse);
    code.statistics.defines=defines;
    
    fprintf('  done creating csparse object (%.3f sec)\n',etime(clock,t_csparse));

    %% Compile code
    fprintf(' creating C code... ');
    t_compile2C=clock();
    compile2C(code,codeType,...
              sprintf('%s.c',classname),...
              sprintf('%s.h',classname),...
              sprintf('%s.log',classname),...
              classFolder,...
              profiling);
    code.statistics.time.compile2C=etime(clock,t_compile2C);
    
    fprintf('  done creating C code (%.3f sec)\n',etime(clock,t_compile2C));

    classhelp{end+1}='% Delete object';
    classhelp{end+1}='clear obj';

    t_createGateway=clock();
    %% Create gateway & compile library
    switch (callType) 
      case 'dynamicLibrary'
        statistics=createGateway('template',template,...
                      'CfunctionsSource',fsfullfile(classFolder,sprintf('%s.c',classname)),...
                      'callType','dynamicLibrary',...
                      'dynamicLibrary',classname,'absolutePath',absolutePath,...
                      'folder',folder,...
                      'className',classname,'classHelp',classhelp,...
                      'targetComputer',targetComputer,...
                      'compilerOptimization',compilerOptimization,...
                      'compileGateways',compileGateways,...
                      'compileLibrary',compileLibrary,...
                      'compileStandalones',compileStandalones,...
                      'verboseLevel',verboseLevel);
      case 'client-server'
        statistics=createGateway('template',template,...
                      'CfunctionsSource',fsfullfile(classFolder,sprintf('%s.c',classname)),...
                      'folder',folder,...
                      'className',classname,'classHelp',classhelp,...
                      'callType','client-server','serverProgramName',serverProgramName,...
                      'serverComputer',serverComputer,...
                      'serverAddress',serverAddress,'port',port,...
                      'targetComputer',targetComputer,...
                      'compilerOptimization',compilerOptimization,...
                      'compileGateways',compileGateways,...
                      'compileLibrary',compileLibrary,...
                      'compileStandalones',compileStandalones,...
                      'verboseLevel',verboseLevel);
    end
    code.statistics.time.createGateway=etime(clock,t_createGateway);
    code.statistics.createGateway=statistics;
    
    fprintf('  done creating & compiling gateways & library (%.2f sec)\n',...
            etime(clock,t_createGateway));

    if verboseLevel>3
        for i=1:length(template)
            fprintf('    mexFunction(%d): %s\n',i,template(i).MEXfunction);
                if length(template(i).inputs)>0
                    for j=1:length(template(i).inputs);
                        fprintf('          input(%d):\n',j);
                        fprintf('                    type(%d): %s\n',...
                                j,template(i).inputs(j).type);
                        fprintf('                    name(%d): %s\n',...
                                j,template(i).inputs(j).name);
                        fprintf('                    size(%d): %s\n',...
                                j,index2str(template(i).inputs(j).sizes));
                    end
                end
                if length(template(i).outputs)>0
                    for j=1:length(template(i).outputs);
                        fprintf('          output(%d):\n',j);
                        fprintf('                    type(%d): %s\n',...
                                j,template(i).outputs(j).type);
                        fprintf('                    name(%d): %s\n',...
                                j,template(i).outputs(j).name);
                        fprintf('                    size(%d): %s\n',...
                                j,index2str(template(i).outputs(j).sizes));
                    end
                end
        end
    end

    %% debug info to be passed to debugConvergenceAnalysis
    
    debugInfo.P1optimizationVariables=P1optimizationVariables;
    debugInfo.P2optimizationVariables=P2optimizationVariables;
    debugInfo.P1constraints=P1constraints;
    debugInfo.P2constraints=P2constraints;
    
    code.statistics.time.cmexCS=etime(clock,t_cmexCS);
    fprintf('done cmex2equilibriumLatentCS (%.3f sec)\n',etime(clock,t_cmexCS));

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% Set outputs
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    varargout=setOutputs(nargout,params);

end
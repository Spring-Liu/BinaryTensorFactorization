% function [U lambda pr co_lambda co_pr llikevec time_trace] = BTF_JointOnlineGibbs(co_xi,co_id,xi,id,xi_test,idtest,R,batchsize,numiters,isbatch)
function [U lambda pr co_lambda co_pr llikevec time_trace] = BTF_JointCountOnlineGibbs(co_xi,co_id,xi,id,R,batchsize,co_batchsize,numiters,isbatch,co_isbatch)
    K=length(id);
    for k=1:K 
        N(k) = max(id{k}); 
    end
    rng(0);
    % initial parameters of the dirichlet on U
    a=5e-1*ones(1,K);
    for k=1:K
        for r=1:R
            dir_a{k,r} = a(k)*ones(N(k),1);
        end
    end    
    U=cell(1,K);
    for k=1:K
        U{1,k} = sampleDirMat(a(k)*ones(1,N(k)),R);
        U{1,k} = U{1,k}';
    end
    
    % initial parameters of the beta on pr
    c=1;epsi=1/R;pr_a = c*epsi;pr_b = c*(1-epsi);
%     pr=betarnd(pr_a,pr_b);
    pr=pr_a/(pr_a+pr_b);  
    co_pr=pr;
    
    % initial parameters of the gamma on lambda
    gr=0.1;lambda_a = gr*ones(1,R);lambda_b = (pr/(1-pr))*ones(1,R);
%     lambda=gamrnd(gr,pr/(1-pr),1,R);
    lambda=gr*pr/(1-pr)*ones(1,R);
    co_lambda=lambda;
    
    Nnon0=length(id{1,1});
    startid=find(id{1}==1000);% index for the 1000th author
    Train=startid(1)-1;%floor(0.1*Nnon0);
%     idall=randperm(Nnon0);
    idall=1:Nnon0;
    idtest=cell(1,K);
    for k=1:K
        idtest{k} = id{k}(idall(Train+1:end)); 
    end  
    co_Nnon0=length(co_id{1});
    co_Train=floor(1*co_Nnon0);
    co_idall=randperm(co_Nnon0);
    co_idtest=cell(1,2);
    for k=1:2
        co_idtest{k} = co_id{k}(co_idall(co_Train+1:end)); 
    end  
    
    perc=1;% fraction of total training data   
    iterN=numiters;
    if isbatch
        Np = Train;
    else
        Np=batchsize;
%         Np=floor(Train*perc*0.1);
    end    
    if co_isbatch
        co_Np=co_Train;
    else
        co_Np=co_batchsize;
%         Np=floor(Train*perc*0.1);
    end
    
    llikevec=zeros(iterN,1);
    t0 = 0;
    tic;
    for iter=1:iterN
        if isbatch
            gam_t = 1;
        else
            gam_t = (iter+t0)^(-0.5);
        end
        
        idselect = [];
        n_tmp = randperm(floor(Train*perc));
        idid = n_tmp(1:Np);
        idid=idall(idid);
        xiselect = xi(idid);
        for k=1:K
            idselect(:, k) = id{1, k}(idid);      
        end
        
        co_idselect =cell(1,2);
        co_n_tmp = randperm(floor(co_Train*perc));
        co_idid = co_n_tmp(1:co_Np);
        co_idid=co_idall(co_idid);
        co_xiselect = co_xi(co_idid);
        for k=1:2
            co_idselect{k}= co_id{1, k}(co_idid);      
        end

        if iter==1
            zetair=computezetair_new(U,idselect,lambda);
            xiselectr=repmat(xiselect,1,R).*zetair;          
            [xsumr,xr]=tensorsum(xiselectr,idselect,N);
            xr=xr*Train/Np;
            for k=1:K
                xsumr{k}= xsumr{k}*Train/Np;
            end
            
            co_zetair=counormalzetair(U{1},co_idselect,co_lambda);
            co_zetai=sum(co_zetair,2);
            
%             co_xiselectlatent=truncated_Poisson_rnd_1(co_xi',co_zetai);
            co_xiselectlatent=co_zetai.*exp(co_zetai)./(exp(co_zetai)-1);
            co_xiselectr=repmat(co_xiselectlatent,1,R).*co_zetair./repmat(co_zetai,1,R);
            [co_xsumr,co_xr]=cotensorsum(co_xiselectr,co_id,N(1));
            co_xr=co_xr*co_Train/co_Np;
            co_xsumr{1}=co_xsumr{1}*co_Train/co_Np;
        else
            zetair=computezetair_new(U,idselect,lambda);
            xiselectr=repmat(xiselect,1,R).*zetair;
            [xsumr_temp,xr_temp]=tensorsum(xiselectr,idselect,N);           
            xr = (1-gam_t)*xr_old + gam_t*xr_temp*Train/Np;
            for k=1:K
                xsumr{k}=(1-gam_t)*xsumr_old{k} + gam_t*xsumr_temp{k}*Train/Np;
            end
            co_zetair=counormalzetair(U{1},co_idselect,co_lambda);
            co_zetai=sum(co_zetair,2);
%             co_xiselectlatent=truncated_Poisson_rnd_1(co_xi',co_zetai);
            co_xiselectlatent=co_zetai.*exp(co_zetai)./(exp(co_zetai)-1);
            co_xiselectr=repmat(co_xiselectlatent,1,R).*co_zetair./(repmat(co_zetai,1,R));
            [co_xsumr_temp,co_xr_temp]=cotensorsum(co_xiselectr,co_id,N(1));
        
            if co_isbatch==0
                co_xr = (1-gam_t)*co_xr_old + gam_t*co_xr_temp*co_Train/co_Np;
                co_xsumr{1}=(1-gam_t)*co_xsumr_old{1} + gam_t*co_xsumr_temp{1}*co_Train/co_Np;
            else
                co_xr=co_xr_temp;
                co_xsumr{1}=co_xsumr_temp{1};
            end
        end
        % update pr
        pr_a = c*epsi+xr;pr_b = c*(1-epsi)+gr;pr = pr_a./(pr_a+pr_b);    
        co_pr_a = c*epsi+co_xr;co_pr_b = c*(1-epsi)+gr;co_pr = co_pr_a./(co_pr_a+co_pr_b);

        % update lambda
        lambda_a = gr+xr;lambda_b = pr;lambda = lambda_a.*lambda_b;       
        co_lambda_a = gr+co_xr;co_lambda_b = co_pr;co_lambda = co_lambda_a.*co_lambda_b;
        
        % update U
        for r=1:R
            for k=1:K
                if k==1
                    dir_a{k,r}(idselect(:, k)) = a(k)+xsumr{1,k}(idselect(:, k),r);
                    dir_a{k,r}(co_id{1}(:,k))=dir_a{k,r}(co_id{1}(:,k))+co_xsumr{1}(co_id{1}(:,k),r);
                else
                    dir_a{k,r}(idselect(:, k)) = a(k)+xsumr{1,k}(idselect(:, k),r);
                end
                U{1,k}(:,r) = dir_a{k,r}'/sum(dir_a{k,r});            
             end       
        end
        xr_old = xr;
        xsumr_old = xsumr;
        
        co_xr_old=co_xr;
        co_xsumr_old=co_xsumr;

        if iter==1 
            time_trace(iter) = toc;
            tic;
        else
            time_trace(iter) = time_trace(iter-1) + toc;
            tic;
        end 
 
        [llike mae rmse mse]=evaluation_pois(xi(idall(Train+1:end)),idtest,U,lambda);
        llikevec(iter)=llike;rmsevec(iter)=rmse;maevec(iter)=mae;msevec(iter)=mse;
        fprintf('iteration= %d;loglikelihood= %f, mae=%f, mse=%f, rmse=%f, time elapsed= %f\n', iter, llike/(Nnon0-Train), mae, mse, rmse, time_trace(iter));
    
        subplot(3,1,1); plot(time_trace(1:iter),llikevec(1:iter));
        xlabel('Time (seconds)');
        ylabel('Heldout log-likelihood'); 
        subplot(3,1,2);plot(sort(lambda,'descend'));
        xlabel('Weights of rank-1 components-Tensor');
        subplot(3,1,3);plot(sort(co_lambda,'descend'));
        xlabel('Weights of rank-1 components-Matrix');       
        drawnow;
    end
end
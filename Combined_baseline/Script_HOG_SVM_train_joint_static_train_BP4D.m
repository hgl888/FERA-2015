function Script_HOG_SVM_train_joint_static_train_BP4D()

% Change to your downloaded location
addpath('C:\liblinear\matlab')
addpath('../data extraction/');
%% load shared definitions and AU data

% Set up the hyperparameters to be validated
hyperparams.c = 10.^(-6:1:3);
% hyperparams.e = 10.^(-6:1:-1);
hyperparams.e = 10.^(-3);

hyperparams.validate_params = {'c', 'e'};

% Set the training function
svm_train = @svm_train_linear;
    
% Set the test function (the first output will be used for validation)
svm_test = @svm_test_linear;

pca_loc = '../pca_generation/generic_face_rigid.mat';

aus = [2,12,17];

%%
for a=1:numel(aus)
    
    au = aus(a);

    rest_aus = setdiff(aus, au);        

    od = cd('../SEMAINE_baseline/');
    find_SEMAINE;
    % load the training and testing data for the current fold
    [train_samples_semaine, train_labels_semaine, valid_samples_semaine, valid_labels_semaine, ~, PC, means, scaling] = Prepare_HOG_AU_data_generic(train_recs, devel_recs, au, rest_aus, SEMAINE_dir, hog_data_dir, pca_loc);
    cd(od)
    
    od = cd('../BP4D_baseline/');
    find_BP4D;
    [train_samples_bp4d, train_labels_bp4d, valid_samples_bp4d, valid_labels_bp4d, ~, ~, ~, ~] = Prepare_HOG_AU_data_generic(train_recs, devel_recs, au, BP4D_dir, hog_data_dir, pca_loc);
    cd(od);
    
    find_DISFA;
    od = cd('../DISFA_baseline/training/');
    all_disfa = [1,2,4,5,6,9,12,15,17,20,25,26];
    rest_aus = setdiff(all_disfa, au);    
    [train_samples_disfa, train_labels_disfa, valid_samples_disfa, valid_labels_disfa, ~, ~, ~, ~] = Prepare_HOG_AU_data_generic(users, au, rest_aus, hog_data_dir);            
    % Binarise the models            
    valid_labels_disfa(valid_labels_disfa < 1) = 0;
    valid_labels_disfa(valid_labels_disfa >= 1) = 1;
    
    train_labels_disfa(train_labels_disfa < 1) = 0;
    train_labels_disfa(train_labels_disfa >= 1) = 1;
    
    cd(od);
    
    valid_samples = cat(1, valid_samples_semaine, valid_samples_bp4d, valid_samples_disfa);
    valid_labels = cat(1, valid_labels_semaine, valid_labels_bp4d, valid_labels_disfa);            

    train_samples = train_samples_bp4d;
    train_labels = train_labels_bp4d;
    
    train_samples = sparse(train_samples);
    valid_samples = sparse(valid_samples);
        
    %% Cross-validate here                
    [ best_params, ~ ] = validate_grid_search(svm_train, svm_test, false, train_samples, train_labels, valid_samples, valid_labels, hyperparams);

    model = svm_train(train_labels, train_samples, best_params);        

    [prediction_semaine, a, actual_vals] = predict(valid_labels_semaine, sparse(valid_samples_semaine), model);
    [prediction_bp4d, a, actual_vals] = predict(valid_labels_bp4d, sparse(valid_samples_bp4d), model);
    [prediction_disfa, a, actual_vals] = predict(valid_labels_disfa, sparse(valid_samples_disfa), model);
    
    % Go from raw data to the prediction
    w = model.w(1:end-1)';
    b = model.w(end);

    svs = bsxfun(@times, PC, 1./scaling') * w;

    % Attempt own prediction
%     preds_mine = bsxfun(@plus, raw_valid, -means) * svs + b;

%     assert(norm(preds_mine - actual_vals) < 1e-8);

    name = sprintf('camera_ready/AU_%d_static_combined_bp4d.dat', au);

    pos_lbl = model.Label(1);
    neg_lbl = model.Label(2);

    write_lin_svm(name, means, svs, b, pos_lbl, neg_lbl);

    name = sprintf('camera_ready/AU_%d_static_combined_bp4d.mat', au);

    tp_semaine = sum(valid_labels_semaine == 1 & prediction_semaine == 1);
    fp_semaine = sum(valid_labels_semaine == 0 & prediction_semaine == 1);
    fn_semaine = sum(valid_labels_semaine == 1 & prediction_semaine == 0);
    tn_semaine = sum(valid_labels_semaine == 0 & prediction_semaine == 0);

    precision_semaine = tp_semaine/(tp_semaine+fp_semaine);
    recall_semaine = tp_semaine/(tp_semaine+fn_semaine);

    f1_semaine = 2 * precision_semaine * recall_semaine / (precision_semaine + recall_semaine);    

    tp_bp4d = sum(valid_labels_bp4d == 1 & prediction_bp4d == 1);
    fp_bp4d = sum(valid_labels_bp4d == 0 & prediction_bp4d == 1);
    fn_bp4d = sum(valid_labels_bp4d == 1 & prediction_bp4d == 0);
    tn_bp4d = sum(valid_labels_bp4d == 0 & prediction_bp4d == 0);

    precision_bp4d = tp_bp4d/(tp_bp4d+fp_bp4d);
    recall_bp4d = tp_bp4d/(tp_bp4d+fn_bp4d);

    f1_bp4d = 2 * precision_bp4d * recall_bp4d / (precision_bp4d + recall_bp4d);    
      
    tp_disfa = sum(valid_labels_disfa == 1 & prediction_disfa == 1);
    fp_disfa = sum(valid_labels_disfa == 0 & prediction_disfa == 1);
    fn_disfa = sum(valid_labels_disfa == 1 & prediction_disfa == 0);
    tn_disfa = sum(valid_labels_disfa == 0 & prediction_disfa == 0);

    precision_disfa = tp_disfa/(tp_disfa+fp_disfa);
    recall_disfa = tp_disfa/(tp_disfa+fn_disfa);

    f1_disfa = 2 * precision_disfa * recall_disfa / (precision_disfa + recall_disfa); 
    
    save(name, 'model', 'f1_semaine', 'precision_semaine', 'recall_semaine', 'f1_bp4d', 'precision_bp4d', 'recall_bp4d', 'f1_disfa', 'precision_disfa', 'recall_disfa');

end

end

function [model] = svm_train_linear(train_labels, train_samples, hyper)
    comm = sprintf('-s 1 -B 1 -e %f -c %f -q', hyper.e, hyper.c);
    model = train(train_labels, train_samples, comm);
end

function [result, prediction] = svm_test_linear(test_labels, test_samples, model)

    w = model.w(1:end-1)';
    b = model.w(end);

    % Attempt own prediction
    prediction = test_samples * w + b;
    l1_inds = prediction > 0;
    l2_inds = prediction <= 0;
    prediction(l1_inds) = model.Label(1);
    prediction(l2_inds) = model.Label(2);
 
    %[prediction, a, actual_vals] = predict(test_labels, test_samples, model);           
    
    tp = sum(test_labels == 1 & prediction == 1);
    fp = sum(test_labels == 0 & prediction == 1);
    fn = sum(test_labels == 1 & prediction == 0);
    tn = sum(test_labels == 0 & prediction == 0);

    precision = tp/(tp+fp);
    recall = tp/(tp+fn);

    f1 = 2 * precision * recall / (precision + recall);

%     result = corr(test_labels, prediction);
    fprintf('F1:%.3f\n', f1);
    if(isnan(f1))
        f1 = 0;
    end
    result = f1;
end

function [outputs,misclassified] = SVMClassifier(features,targets)

inputs = features;
targets = targets;

P = 0.7 % Percentage held out
[train, test] = crossvalind('HoldOut', targets, P);
cp = classperf(targets); % Initialize CP object
% Train the Network
SVMStruct = svmtrain(inputs(train,:),targets(train));

% Test the Network
outputs = svmclassify(SVMStruct,inputs(test,:),'ShowPlot',true);

classperf(cp,outputs,test) % Update class performance object
misclassified = cp.ErrorRate
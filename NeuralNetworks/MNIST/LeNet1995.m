(* ::Package:: *)

(*
   See Yann Le Cunn et al 1995:

http://yann.lecun.com/exdb/publis/pdf/lecun-95b.pdf

Network Architecture: Large Fully Connected Multi-Layer Neural Network
                      400-300-10

They claim 1.6% test result

Our Results:    NEEDS MORE TRAINING!!!
Iteration: 66
Training Loss: .638
Training Classification: 81.1%

Validation Loss: .597
Validation Classification: 83.0%
*)


<<"C:/users/julian/documents/github/Machine-Vision/NeuralNetworks/NeuralNetwork.m"


<<"C:/users/julian/documents/github/Machine-Vision/NeuralNetworks/MNIST/MNISTData.m"


MNISTLeNet95Network={
   Adaptor2DTo1D[20],
   FullyConnected1DTo1D[ConstantArray[0.,300],Partition[Table[Random[],{300*400}]/400.,400]],Tanh,
   FullyConnected1DTo1D[ConstantArray[0.,10],Partition[Table[Random[],{3000}]/300.,300]],
   Softmax};


MNISTLeNet95TrainingInputs=TrainingImages[[1;;50000,5;;24,5;;24]]*1.;
MNISTLeNet95TrainingOutputs=Map[ReplacePart[ConstantArray[0,10],(#+1)->1]&,TrainingLabels[[1;;50000]]];

MNISTLeNet95ValidationInputs=TrainingImages[[50001;;60000,5;;24,5;;24]]*1.;
MNISTLeNet95ValidationOutputs=Map[ReplacePart[ConstantArray[0,10],(#+1)->1]&,TrainingLabels[[50001;;60000]]];


 MNISTLeNet95Train:=AdaptiveGradientDescent[
   MNISTLeNet95Network,MNISTLeNet95TrainingInputs,MNISTLeNet95TrainingOutputs,
   Grad,ClassificationLoss,
     {MaxLoop->500000,
      ValidationInputs->MNISTLeNet95ValidationInputs,
      ValidationTargets->MNISTLeNet95ValidationOutputs}];

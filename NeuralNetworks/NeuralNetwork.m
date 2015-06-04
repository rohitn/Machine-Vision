(* ::Package:: *)

(*
   network is made up of sequence of layers
   layer is made up of biases for each of the units
   followed by the weight vector for each unit,
   so weight is a matrix where each row is the weight vector
   for one particular unit

   Layer L has U units and preceeding layer has P units
   then network layer looks like (U*1,U*P)

   The linear activation layer looks like U*T where T is the
   number of inputs or training examples

   inputs has shape I*T where I is the number of inputs
   output is of shape O*T
*)

FullyConnectedForwardPropogation[inputs_,parameters_]:=(
   Z0 = inputs;

   layer1=parameters[[1]];
   Assert[(layer1[[2,1]]//Length)==(Z0//Length)]; (* Incoming weight matrix should match up with number of units from previous layer *)
   Assert[(layer1[[1]]//Length)==(layer1[[2]]//Length)]; (*Bias on units should match up with number of units from weight layer *)
   A1=layer1[[2]].Z0 + layer1[[1]];
   Z1 = Tanh[A1];

   layer2=parameters[[2]];
   Assert[(layer2[[2,1]]//Length)==(Z1//Length)]; (* Incoming weight matrix should match up with number of units from previous layer *)
   Assert[(layer2[[1]]//Length)==(layer2[[2]]//Length)]; (*Bias on units should match up with number of units from weight layer *)
   A2=layer2[[2]].Z1 + layer2[[1]];
   Z2 = Tanh[A2]
)

(* INCOMPLETE *)
(*
   The linear activation layer has shape U*T 
   DeltaXX refers to the partial derivative of the loss function wrt that neurone activation
      so it has shape U*T
   targets has shape O*T where O is the number of output units
*)
FullyConnectedGrad[currentParameters_,inputs_,targets_]:=(

   FullyConnectedForwardPropogation[inputs, currentParameters];

   DeltaZ2=2*(Z2-targets); (*We are implicitly assuming a regression loss function*)
   DeltaA2=DeltaZ2*Sech[A2]^2;

   DeltaZ1=Transpose[layer2[[2]]].DeltaA2;
   DeltaA1=DeltaZ1*Sech[A1]^2;

   {{Total[DeltaZ1,{2}],DeltaZ1.Transpose[inputs]},{Total[DeltaA2,{2}],DeltaA2.Transpose[Z1]}}
)

(*This is implicitly a regression loss function*)
Loss[parameters_,inputs_,targets_]:=Total[(FullyConnectedForwardPropogation[inputs,parameters]-targets)^2,2]

GradientDescent[initialParameters_,inputs_,targets_,maxLoop_:2000]:=(
   Print["Iter: ",Dynamic[loop],"Current Loss", Dynamic[Loss[wl,inputs,targets]]];
   For[wl=initialParameters;loop=1,loop<=maxLoop,loop++,wl-=.0001*FullyConnectedGrad[wl,inputs,targets]];
   wl )

Visualise[parameters_]:=(

   Z0 = Table[0,{layer1[[2,1]]//Length}];
   Print[Z0//Length," Inputs"];

   layer1=parameters[[1]];
   Assert[(layer1[[2,1]]//Length)==(Z0//Length)]; (* Incoming weight matrix should match up with number of units from previous layer *)
   Assert[(layer1[[1]]//Length)==(layer1[[2]]//Length)]; (*Bias on units should match up with number of units from weight layer *)

   Z1 = Table[0,{layer1[[1]]//Length}];
   Print[Z1//Length," H1 Units"];

   layer2=parameters[[2]];
   Assert[(layer2[[2,1]]//Length)==(Z1//Length)]; (* Incoming weight matrix should match up with number of units from previous layer *)
   Assert[(layer2[[1]]//Length)==(layer2[[2]]//Length)]; (*Bias on units should match up with number of units from weight layer *)
)


(* Examples *)
sqNetwork={
   {{.2,.3},{{2},{3}}},
   {{.6},{{1,7}}}
};
sqInputs={Table[x,{x,0,1,0.1}]};sqInputs//MatrixForm;
sqOutputs=sqInputs^2;sqOutputs//MatrixForm;

sqTrained:=GradientDescent[sqNetwork,sqInputs,sqOutputs,500000];

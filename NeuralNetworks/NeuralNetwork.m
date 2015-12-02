(* ::Package:: *)

<<"C:/users/julian/documents/github/Machine-Vision/MVTools.m"
<<"C:/users/julian/documents/github/Machine-Vision/NeuralNetworks/NeuralLayers.m"


AbortAssert[bool_,message_]:=
   If[bool==False,
      Print[message];Abort[]];

LayerName[s_Symbol]:=ToString[SymbolName[s]]
LayerName[h_]:=ToString[Head[h]]


(*
   network is made up of sequence of layers
   layer is made up of biases for each of the units
   followed by the weight vector for each unit,
   so weight is a matrix where each row is the weight vector
   for one particular unit
*)
ForwardPropogateLayers[inputs_,network_]:=
(* We don't include the inputs *)
   Rest[FoldList[
      Timer["ForwardPropogateLayer::"<>LayerName[#2],ForwardPropogateLayer[#1,#2]]&,inputs,network]]

ForwardPropogate[inputs_,network_]:=MemoryConstrained[
   ForwardPropogateLayers[inputs,network][[-1]],
   If[$VersionNumber<9,3 10^9,10^10]]


Options[BackPropogation] = { L1A->0.0 };
SyntaxInformation[L1A]={"ArgumentsPattern"->{}};
BackPropogation[currentParameters_,inputs_,targets_,lossF_,OptionsPattern[]]:=(

   xL1A = OptionValue[L1A];

   L = Timer["ForwardPropogateLayers",ForwardPropogateLayers[inputs, currentParameters]];
   networkLayers=Length[currentParameters];

   AbortAssert[Dimensions[L[[networkLayers]]]==Dimensions[targets],"BackPropogation::Dimensions of outputs and targets should match"];

   DeltaL[networkLayers]=DeltaLoss[lossF,L[[networkLayers]],targets];

   For[layerIndex=networkLayers,layerIndex>1,layerIndex--,
(* layerIndex refers to layer being back propogated across
   ie computing delta's for layerIndex-1 given layerIndex *)

      Timer["Backprop Layer "<>LayerName[currentParameters[[layerIndex]]],
      Which[
         MatchQ[currentParameters[[layerIndex]],MaxPoolingFilterBankToFilterBank],
            DeltaL[layerIndex-1]=BackPropogateLayer[currentParameters[[layerIndex]],L[[layerIndex-1]],L[[layerIndex]],DeltaL[layerIndex]];,
         MatchQ[currentParameters[[layerIndex]],Softmax],
            DeltaL[layerIndex-1]=BackPropogateLayer[currentParameters[[layerIndex]],L[[layerIndex]],DeltaL[layerIndex]];,
         MatchQ[currentParameters[[layerIndex]],Tanh],
            DeltaL[layerIndex-1]=BackPropogateLayer[currentParameters[[layerIndex]],L[[layerIndex-1]],DeltaL[layerIndex]];,
         MatchQ[currentParameters[[layerIndex]],Logistic],
            DeltaL[layerIndex-1]=BackPropogateLayer[currentParameters[[layerIndex]],L[[layerIndex-1]],DeltaL[layerIndex]];,
         MatchQ[currentParameters[[layerIndex]],ReLU],
            DeltaL[layerIndex-1]=BackPropogateLayer[currentParameters[[layerIndex]],L[[layerIndex-1]],DeltaL[layerIndex]];,
         MatchQ[currentParameters[[layerIndex]],MaxConvolveFilterBankToFilterBank],
            DeltaL[layerIndex-1]=BackPropogateLayer[currentParameters[[layerIndex]],L[[layerIndex-1]],L[[layerIndex]],DeltaL[layerIndex]];,
         True,
            DeltaL[layerIndex-1]=BackPropogateLayer[currentParameters[[layerIndex]],DeltaL[layerIndex]];
      ];]

      AbortAssert[Dimensions[DeltaL[layerIndex-1]]==Dimensions[L[[layerIndex-1]]]];
      DeltaL[layerIndex-1]+=Sign[L[[layerIndex-1]]]*xL1A;
   ];
)

(*
   The linear activation layer has shape T*U 
   DeltaXX refers to the partial derivative of the loss function wrt that neurone activation
      so it has shape T*U
   targets has shape T*O where O is the number of output units
*)
Options[NNGrad] = {};
NNGrad[currentParameters_,inputs_,targets_,lossF_,opts:OptionsPattern[]]:=(

   AbortAssert[Length[inputs]==Length[targets],"NNGrad::# of Training Labels should equal # of Training Inputs"];

   Timer["BackPropogation Total",
   BackPropogation[currentParameters,inputs,targets,lossF,FilterRules[{opts}, Options[BackPropogation]]];];

   Timer["LayerGrad",
   Prepend[
      Table[
         Timer["LayerGrad::"<>LayerName[currentParameters[[layerIndex]]],GradLayer[currentParameters[[layerIndex]],L[[layerIndex-1]],DeltaL[layerIndex]]]
         ,{layerIndex,2,Length[currentParameters]}],
      GradLayer[currentParameters[[1]],inputs,DeltaL[1]]
   ]]
)

(*
Deprecated: harder than it looks to implement, be careful with normalising sizes and mixing with only half batches
MemConstrainedGrad[currentParameters_,inputs_,targets_,lossF_]:=
      Total[MapThread[Grad[currentParameters,#1,#2,lossF]&,{Partition[inputs,500,500,{+1,+1},{}],Partition[targets,500,500,{+1,+1},{}]}]]
*)

DeltaLoss[RegressionLoss1D,outputs_,targets_]:=2.0*(outputs-targets)/Length[outputs];
DeltaLoss[RegressionLoss2D,outputs_,targets_]:=2.0*(outputs-targets)/Length[outputs];
DeltaLoss[RegressionLoss3D,outputs_,targets_]:=2.0*(outputs-targets)/Length[outputs];
DeltaLoss[ClassificationLoss,outputs_,targets_]:=-targets*(1.0/outputs)/Length[outputs];
DeltaLoss[CrossEntropyLoss,outputs_,targets_]:=-((-(1-targets)/(1-outputs)) + (targets/outputs))/Length[outputs];

(*This is implicitly a regression loss function*)
RegressionLoss1D[parameters_,inputs_,targets_]:=(outputs=ForwardPropogate[inputs,parameters];AbortAssert[Dimensions[outputs]==Dimensions[targets],"Loss1D::Mismatched Targets and Outputs"];Total[(outputs-targets)^2,2]/Length[inputs]);
RegressionLoss2D[parameters_,inputs_,targets_]:=Total[(ForwardPropogate[inputs,parameters]-targets)^2,3]/Length[inputs];
RegressionLoss3D[parameters_,inputs_,targets_]:=Total[(ForwardPropogate[inputs,parameters]-targets)^2,4]/Length[inputs];
ClassificationLoss[parameters_,inputs_,targets_]:=-Total[Log[Extract[ForwardPropogate[inputs,parameters],Position[targets,1]]]]/Length[inputs];
CrossEntropyLoss[parameters_,inputs_,targets_]:=
   -Total[targets*Log[ForwardPropogate[inputs,parameters]]+(1-targets)*Log[1-ForwardPropogate[inputs,parameters]],2]/Length[inputs];

WeightDec[networkLayers_List,grad_List]:=MapThread[WeightDec,{networkLayers,grad}]

LineSearch[{\[Lambda]_,v_,current_},objectiveF_]:=
(* This is implicitly a lowest line search *)(
   t\[Lambda]=\[Lambda]*1.1; (*Has an optimism bias*)
   While[(loss=objectiveF[t\[Lambda]*v])>current,t\[Lambda]=t\[Lambda]*.5;AbortAssert[t\[Lambda]>10^-30]];
  {t\[Lambda],loss}
);

NullFunction[]=Function[{},(Null)];
Options[GenericGradientDescent] = { MaxEpoch -> 20000,
   StepMonitor->NullFunction, InitialLearningRate->.01,
   ValidationInputs->{},ValidationTargets->{},
   Momentum->0.0,
   MomentumType->"CM",
   L1A->0.0
};
SyntaxInformation[MaxEpoch]={"ArgumentsPattern"->{}};
SyntaxInformation[ValidationInputs]={"ArgumentsPattern"->{}};
SyntaxInformation[ValidationTargets]={"ArgumentsPattern"->{}};
SyntaxInformation[InitialLearningRate]={"ArgumentsPattern"->{}};
SyntaxInformation[Momentum]={"ArgumentsPattern"->{}};
SyntaxInformation[MomentumType]={"ArgumentsPattern"->{}};
GenericGradientDescent[initialParameters_,inputs_,targets_,gradientF_,lossF_,algoF_,opts:OptionsPattern[]]:=(

   trainingLoss=\[Infinity];
   validationLoss=\[Infinity];

   \[Lambda] = OptionValue[InitialLearningRate];
   Print["Epoch: ",Dynamic[epoch]," Training Loss ",Dynamic[trainingLoss], " \[Lambda]=",Dynamic[\[Lambda]]];
   If[OptionValue[ValidationInputs]!={},Print[" Validation Loss ",Dynamic[validationLoss]]];
   Print[Dynamic[grOutput]];
   For[wl=initialParameters;epoch=1,epoch<=OptionValue[MaxEpoch],epoch++,
      algoF[];
      If[OptionValue[ValidationInputs]!={},
        (*Note the validation can be done here as it is assumed it is small enough to compute in memory*)
         validationLoss=lossF[wl,OptionValue[ValidationInputs],OptionValue[ValidationTargets]];
         AppendTo[ValidationHistory,validationLoss];,
         0];
      AppendTo[TrainingHistory,trainingLoss];
      OptionValue[StepMonitor][];
   ]);

GradientDescent[initialParameters_,inputs_,targets_,gradientF_,lossF_,opts:OptionsPattern[]]:=
   GenericGradientDescent[initialParameters,inputs,targets,gradientF,lossF,
      (  gw=gradientF[wl,inputs,targets,lossF,opts];
         wl=WeightDec[wl,\[Lambda]*gw];
         trainingLoss=lossF[wl,inputs,targets];)&,
      opts];

AdaptiveGradientDescent[initialParameters_,inputs_,targets_,gradientF_,lossF_,opts:OptionsPattern[]]:=
   GenericGradientDescent[initialParameters,inputs,targets,gradientF,lossF,
      (  gw=gradientF[wl,inputs,targets,lossF,opts];
         {\[Lambda],trainingLoss}=LineSearch[{\[Lambda],gw,trainingLoss},lossF[WeightDec[wl,#],inputs,targets]&];
         wl=WeightDec[wl,\[Lambda]*gw];
         trainingLoss=lossF[wl,inputs,targets];)&,
      opts];


Options[MiniBatchGradientDescent] = { MaxEpoch -> 20000,
   StepMonitor->NullFunction, InitialLearningRate->.01,
   ValidationInputs->{},ValidationTargets->{},
   Momentum->0.0,
   MomentumType->"CM",
   L1A->0.0
};
(* http://www.cs.toronto.edu/~fritz/absps/momentum.pdf *)
(* On the importance of initialization and momentum in deep learning *)
(* Sutskever, Martens, Dahl, Hinton (2013) *)
MiniBatchGradientDescent[initialParameters_,inputs_,targets_,gradientF_,lossF_,opts:OptionsPattern[]]:=(
   Print["Batch #:", Dynamic[batch], " Partial: ",Dynamic[partialTrainingLoss[[-1]]]];
   velocity=0.0;initMB=0;
   GenericGradientDescent[initialParameters,inputs,targets,gradientF,lossF,
      (  partialTrainingLoss={};batch=0;
         MapThread[
            (
            batch++;
            gw=If[OptionValue[MomentumType]!="Nesterov"||initMB==0,gradientF[wl,#1,#2,lossF,opts],gradientF[WeightDec[wl,OptionValue[Momentum]*velocity],#1,#2,lossF,opts]];
            velocity = OptionValue[Momentum]*velocity + \[Lambda]*gw; initMB=1;
            wl=WeightDec[wl,velocity];
            AppendTo[partialTrainingLoss,lossF[wl,#1,#2]];)&,
         {Partition[inputs,100],Partition[targets,100]}];
         trainingLoss = Mean[partialTrainingLoss])&,
      opts];)


Checkpoint[f_,skip_:10]:=Function[{},If[Mod[epoch,skip]==1,f[],0]]


NNBaseDir="C:\\Users\\Julian\\Documents\\GitHub\\Machine-Vision\\NeuralNetworks\\";
NNBaseDir="C:\\Users\\Julian\\Google Drive\\Personal\\Computer Science\\WebMonitor\\";

(* Note learning rate .01 reference: http://arxiv.org/pdf/1206.5533v2.pdf, page 9 *)
NNInitialise[resourceName_,network_,learningRate_:0.01]:=
   Export[NNBaseDir<>resourceName<>".wdx",{{},{},network,learningRate}]

NNRead[resourceName_String]:=
   (({TrainingHistory,ValidationHistory,wl,\[Lambda]}=
      Import[NNBaseDir<>resourceName<>".wdx"]););

NNWrite[resourceName_String]:=
      Export[NNBaseDir<>resourceName<>".wdx",{TrainingHistory,ValidationHistory,wl,\[Lambda]}];

(* Note Following functions either take no args, or return a function that takes no args
   so they can be used as update functions for example *)
Persist[resourceName_String]:=Function[{},
   NNWrite[resourceName]];

ScreenMonitor[]:=(grOutput=
   ListPlot[
      If[!MatchQ[ValidationHistory,_List],TrainingHistory,{TrainingHistory,ValidationHistory}],
      PlotRange->All,PlotStyle->{Blue,Green}]);

WebMonitor[resourceName_]:=Function[{},
   Export[StringJoin[NNBaseDir,resourceName,".jpg"],
      Rasterize[{Text[trainingLoss],Text[validationLoss],ScreenMonitor[]},ImageSize->800,RasterSize->1000]];];

NNCheckpoint[resourceName_]:=Function[{},(WebMonitor[resourceName][];Persist[resourceName][])];


(*Assuming a 1 of n target representation*)
ClassificationPerformance[network_,inputs_,targets_]:=
   Module[{proc},
   proc=ForwardPropogate[inputs,network];
   Mean[Boole[Table[Position[proc[[t]],Max[proc[[t]]]]==Position[targets[[t]],Max[targets[[t]]]],{t,1,Length[inputs]}]]]//N
];


NNClassify[inputs_,wl_]:=Module[{outputs=ForwardPropogate[inputs,wl]},
   Table[Position[outputs[[t]],Max[outputs[[t]]]][[1,1]],{t,1,Length[inputs]}]-1];


(* Some Test Helping Code *)
CheckGrad[lossF_,weight_,inputs_,targets_]:=
   (lossF[WeightDec[wl,-ReplacePart[gw*0.,weight->10^-8]],inputs,targets]-lossF[wl,inputs,targets])/10^-8

CheckDeltaSensitivity[levelCheck_:6,cellCheck_:{200,16,3,2},targets_]:={
(* Neuron sensitivity checking code *)
(* Advise save L levels in SaveL before running to prevent interference *)
 (* levelCheck: This is the sensitivity of the output neurones at this level *)
(* So note to check backprop you go one before, eg levelCheck 6 is checking neurons are correct at *)
(* level 6, ie backprop iscorrect for level 7 *)
(* cellCheck: {200,16,3,2} *)
   (10^6)*(ClassificationLoss[wl[[levelCheck+1;;-1]],SaveL[levelCheck]+ReplacePart[(SaveL[levelCheck]*0.),cellCheck->10^-6],targets]-
      ClassificationLoss[wl[[levelCheck+1;;-1]],SaveL[levelCheck],targets]),
   Extract[DeltaL[levelCheck],cellCheck]
}


Size[net_,input_]:=(
   Print["# of Parameters ",Level[net,{-1}]//Length]; (*Slightly approx due to symbol vs function ie overcount Tanh etc *)
   Print["# of Neurons ",ForwardPropogateLayers[{input},net]//Flatten//Length];)

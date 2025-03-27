//
//  SherpaModel.swift
//  MNNLLMiOS
//
//  Created by 游薪渝(揽清) on 2025/3/27.
//

import Foundation

func getResource(_ forResource: String, _ ofType: String) -> String {
  let path = Bundle.main.path(forResource: forResource, ofType: ofType)
  precondition(
    path != nil,
    "\(forResource).\(ofType) does not exist!\n" + "Remember to change \n"
      + "  Build Phases -> Copy Bundle Resources\n" + "to add it!"
  )
  return path!
}


func getMNNBilingualStreamZhEnZipformer20230220() -> SherpaOnnxOnlineModelConfig {
  let encoder = getResource("encoder-epoch-99-avg-1.int8", "mnn")
  let decoder = getResource("decoder-epoch-99-avg-1.int8", "mnn")
  let joiner = getResource("joiner-epoch-99-avg-1.int8", "mnn")
  let tokens = getResource("tokens", "txt")

    return sherpaOnnxOnlineModelConfig(
      tokens: tokens,
      transducer: sherpaOnnxOnlineTransducerModelConfig(
        encoder: encoder,
        decoder: decoder,
        joiner: joiner),
      numThreads: 2,
      modelType: "zipformer"
    )
}

# 手机跑大模型，阿里开源的 TaoAvatar 玩起来了！

一个本地运行、完全离线、支持多模态交互的智能数字人App诞生了！这就是阿里巴巴开源的 **MNN TaoAvatar**，带你在安卓手机上零距离感受AI的魅力。


什么是 TaoAvatar？简单来说，它是阿里最新研究成果的落地应用（详见 [TaoAvatar论文](https://arxiv.org/html/2503.17032v1)），将大语言模型（LLM）、语音识别（ASR）、语音合成（TTS）、声音到动作合成（A2BS）、神经渲染（NNR）统统搬到手机端，全本地运行，无需联网！

> 📢 iOS版稍后上线，敬请期待！

## 🌟 特色功能一览

* **本地聊天机器人**：基于本地运行的LLM，实时与数字人畅聊
* **语音识别更智能**：内置ASR模型，即说即转文字
* **随心所欲合成语音**：TTS模型，让你的数字人发声自然真实
* **声音驱动表情动作**：A2BS技术，通过声音自动生成数字人丰富的面部表情和动作
* **实时神经渲染**：让数字人表情细腻逼真，互动感更强
* **100%离线运行**：完全本地运行，守护隐私更放心


## 📱硬件要求

毕竟要把大模型塞进手机，性能可不能太落后。这套App需要：

* **旗舰芯片级性能**：高通骁龙8 Gen 3或联发科天玑9200以上级别
* **内存至少8GB**
* **手机存储需至少5GB空间**用于存放模型文件
* **ARM64架构**

> ⚠️ 性能不足的设备可能会遇到卡顿、声音断续或功能受限哦。

## 🚀 安装与体验步骤

想亲自体验一下？按照下面简单步骤来就好：

1. 克隆项目代码

```bash
git clone https://github.com/alibaba/MNN.git
cd apps/Android/Mnn3dAvatar
```

2. 构建并部署

* 连接你的安卓手机，打开Android Studio点击“Run”，或执行：

```bash
./gradlew installDebug
```

很快，你的智能数字人就上线了！

## 📚 更多相关资源

* [TaoAvatar 论文](https://arxiv.org/html/2503.17032v1)
* [模型合集](https://modelscope.cn/collections/TaoAvatar-68d8a46f2e554a)
* [LLM模型：Qwen2.5-1.5B MNN](https://github.com/alibaba/MNN/tree/master/3rd_party/NNR)
* [TTS模型：bert-vits2-MNN](https://modelscope.cn/models/MNN/bert-vits2-MNN)
* [声音动作模型：UniTalker-MNN](https://modelscope.cn/models/MNN/UniTalker-MNN)
* [神经渲染模型：TaoAvatar-NNR-MNN](https://modelscope.cn/models/MNN/TaoAvatar-NNR-MNN)
* [ASR模型：Sherpa 双语流式识别模型](https://modelscope.cn/models/MNN/sherpa-mnn-streaming-zipformer-bilingual-zh-en-2023-02-20)

马上动手体验一下吧，下一代智能交互，就在你掌中！

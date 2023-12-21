---
title: 推荐系统简单介绍
author: z2z63
date: 2023-08-04 15:26:51
tags: [Mechine Learning]
---
这篇文章是wikipedia的recsys词条的翻译以及简化版本，原文见<https://en.wikipedia.org/wiki/Recommender_system>
recsys(推荐系统)的种类

- collaborative filtering（协同过滤）根据相似用户的行为为用户推荐内容，推荐理由是“与你相似的人都喜欢xx”，
  缺点是需要大量用户行为数据，冷启动慢
- content-based filtering（基于内容过滤）给物打上标签，推荐具有相似标签的物，推荐理由是“与你喜欢的xx有关”，
  少量用户行为数据即可启动，但是只能推荐相似的物，无法推荐新物
- knowledge-based systems

# collaborative filtering

协同过滤的假定是

- 过去相似的用户，在未来也是相似的
- 过去用户喜欢的物，在未来也是喜欢的

推荐系统只使用了不同用户对不同物的评分，通过使用评分，推荐系统定位用户和物，使用邻居生成推荐  
协同推荐的分类

- memory-based 基于内存的协同过滤，例子是user-based algorithm(基于用户的推荐算法)
- model-based，基于模型的协同过滤，例子是matrix factorization（矩阵分解）

优点是不需要机器分析内容（使用NLP分析文本并打上标签等等），能准确推荐复杂的物，缺点是需要大量用户行为数据，冷启动慢

判断用户的相似度使用的算法有

- k-nearest neighbors(kNN算法)
- Pearson correlation coefficient(皮尔逊相关系数)
- approximate nearest neighbors(ANN,近似最近邻算法)

协同过滤的缺点

- 冷启动  
  新用户和新物缺少数据，无法推荐
- 可扩展性  
  随着用户和物的增加，计算量增加，大型推荐系统需要很高的算力
- 稀疏性  
  用户和物的数量都很大，但一个用户只会和极少的物交互，数据很稀疏

item-to-item collaborative filtering（基于物的协同过滤）也是协同过滤的一个例子，它的推荐理由是“喜欢x的人也喜欢y ”

# Content-based filtering

基于内容过滤的推荐系统使用的数据是物的特征（打的标签）和用户的偏好资料，
它将推荐问题转换成了将一群用户分为喜欢某特征和不喜欢某特征的分类问题

为了创建用户偏好资料，推荐系统集中于两种信息

- 用户偏好的模型
- 用户与推荐系统交互的历史

为了获取物的特征，推荐系统常用TF-IDF（又称向量空间表示）算法  
推荐系统基于权重向量创建用户的偏好资料，权重向量中的每一个权重表达了每个特征对用户的重要性。计算权重向量的方法有：
取用户有关的物的权重向量的平均值，还有贝叶斯分类器，聚类分析，决策树，神经网络

基于内容过滤的一个关键问题是，推荐系统不能从一个内容源中学习到用户的偏好然后在其他类型的内容中使用学习到的用户偏好。例如
推荐系统从用户阅读新闻的行为中学习到了用户的偏好，但不能在推荐音乐，视频，产品等物时使用这些偏好。为了克服这个问题，
大多数基于内容过滤的系统都会使用混合式的系统
# Hybrid recommender systems
大多数推荐系统都采用混合式的方案，结合协同过滤、基于内容过滤等等。  
混合式的方案有几种实现方法，可以让不同的推荐系统分别生成推荐然后将结果合并，也可以将协同过滤的能力加入到
基于内容过滤的系统中（或者相反）  
混合式的推荐系统的准确度一般比单一的推荐系统高，而且能够克服单一推荐系统的缺点，例如冷启动和稀疏性问题  
一些混合式的技术有
- Weighted
  将不同推荐系统给一个物的评分求加权平均值，仅仅通过数值的方法来结合不同的推荐系统
- Switching
  在不同的推荐系统中切换，采用所选的系统
- Mixed
  将不同推荐系统的结果合并
- Feature Combination
  将来自不同知识源的特征结合起来，输入给一个推荐系统
- Feature Augmentation
  计算一个或一组特征，其结果作为下一个推荐系统的输入
- Cascade
  不同推荐系统被赋予不同的优先级，当高优先级的推荐系统给一些物打分相同时，低优先级的推荐系统继续打分，改变评分相同的情况
- Meta-level
  一个推荐系统的输出作为另一个推荐系统的输入

---
reference:
[1] wikipedia, Recommender system [https://en.wikipedia.org/wiki/Recommender_system](https://en.wikipedia.org/wiki/Recommender_system)
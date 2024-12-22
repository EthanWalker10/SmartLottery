# 流程

1. 部署 ERC20 合约, 创建我的 token
2. 部署 ERC721 合约， 创建我的 NFT, 这里就先在 mapping 里写死一个 NFT. 然后直接调用 mint 为赢家铸造。NFT 中我只需要
3. 传入 token 合约地址, 部署 Raffle 合约
4. 玩家可以进行注册, 地址将为维护在 s_player 和 balance
5. 传入 token 合约地址和 Raffle 合约地址, 为前 10 名玩家生成 merkle 树, 部署 Airdrop 合约, 并给 Airdrop 合约转账初始空投币, 截至到这里为止, 部署 ERC20 和 merkleAirdrop 的人应该是同一个, 这样才方便将初始空投币转给 Airdrop
6. 然后就可以进行到正常游戏流程:
   1. 每局比赛需要 5 个玩家, 优胜者获得 NFT 奖励(这里以后可以优化, NFT 奖励可以进行品质分级, 游戏需要的玩家数也可以分档)
   2. 
7. 创建 lottery 合约，用户进行注册，维护玩家地址数组
8. 在脚本中动态读取合约中的用户地址，生成 input.json
9. 根据 input.json 生成 output.json
10. 然后就需要让 gasplayer 获取用户的签名信息了, 要 claim 除了 proof 还需要用户的签名信息; proof 直接在 output.json 中拿, 签名信息应该怎么获取? 事实上, 现在可以先简化一点不需要进行签名和验签, 这样就能全流程自动了. (通过 script 自动读取并解析 output.json, 然后直接全部 claim)
   1. 了解签名信息在验证流程中的作用后就可以明确了, 实际上签名信息不影响 merkle proof 的验证
   2. 那么签名信息就可以直接通过前端来调用智能合约的签名生成逻辑
      1. 如果签名生成逻辑函数是 view 或者 pure, 那么可以不消耗 gas. 总的来说有两种方式:
         1. 本地调用, 不消耗gas: 配置 rpc_url, 合约地址, abi 等, 相当于获取函数逻辑然后在本地执行. 
         2. 通过交易调用: 由网络中的节点执行函数逻辑, 仍然需要gas

## 使用 Airdrop 的目的
1. 流程总体是繁琐的, 必须给出足够的理由. 为什么不直接在注册的时候 mint, 而是通过 Airdrop
   1. 游戏合约开发之后其中的逻辑就固定了难以改变. 而使用 Airdrop 可以随时举办类似的活动, 来执行空投; 比如可以为前 100 个用户空投 10 个 token, 也可以为以 '0000' 开头的幸运用户空投; 
2. 上面的流程也可以改为每次创办活动时, 从数组中读取符合条件的地址, 然后为这个地址铸币. 
   1. 一个具备安全性的代币合约, 应该只有授权者才可以铸币, 这样只能由授权者(一般就是代币合约拥有者)来支付 gas 铸币, 不够灵活. 如果使用 Airdrop, 授权者只需要给 Airdrop 铸币, 然后任何人都可以为其中的用户 claim; 此外, 还通过用户自己的意愿(签名信息), 来决定是否接收这份代币. 
   2. 这里需要非常注意: 签名信息其实只是一层加强防护, 是用来验证是否是这个账户本身的意愿, 这层防护是可以不要的, 和验证 merkle proof 没有关系; 验证 merkle proof 只需要 root, proof, leaf(在我们的场景下, leaf 直接根据 account 和 amount 哈希出来就可以了)


##  ERC20 铸币的逻辑
1. 创造一个 ERC20 代币合约之后, 可以为任何人铸币, 这个过程是不需要对方确认的, 因为本质上铸币只是修改了代币合约上的一点数据, 对方除非导入代币合约地址, 不然都感知不到被铸币了. 铸币这个过程, 只是需要花费自己的 gas. 


#


## ERC20
1. block.coinbase 是当前区块的矿工或验证者的地址, 用于接收区块奖励和交易手续费。
2. 创造的代币也是默认以 ether gwei wei 为单位(指后面的0的个数), 当然可以通过 DECIMAL 参数更改, 但是没必要, 保持这样记得换算即可. 



## Airdrop
1. 问题: Airdrop 和直接为用户铸币有什么区别? 尝试解答如下:
   1. 直接为用户铸币, 可能是开发权限给用户自己铸币, 这样用户需要自己支付 gas 费; 也可以是自己给用户铸币, 但是这样需要
   2. 给用户转账: 
2. merkle 树：
   1. output file 中每个结点的 leaf 字段才是自己的 hash 值。proof 是这个节点完成证明需要的 proof
   2. merkle 树本身就是一个静态数据结构, 只要新加入一个节点, 都会改变 root, 因此构建 merkle 树是一个一次性的过程, 在项目中应该等确实满足空投条件(比如有 100 个注册用户)之后, 再构建 merkle 树, 然后创建 Airdrop 合约. 





# 基础知识

## 包管理
1. 试了所有版本, 包结构都和原来的不完全一样, 直接用来最新版, 找到了需要的包的路径进行导入. 
2. 在 Solidity 中，**msg.sender** 始终表示当前直接调用合约的地址。
3. 动态数组中要找一个元素, 复杂度为 O(N), 需要查找玩家, 就建立一个 mapping; 但是 mapping 底层是 hash 表, 不能按顺序输出, 如果还需要按顺序, 那还是需要动态数组



我现在需要以 gasplayer 的账户去调用Airdrop合约中的 claim 函数来为玩家发币, claim函数需要玩家的签名信息, 玩家在前端签名之后, 我应该如何获取这个签名信息并作为




# 实际部署流程
## 1. EthanToken 合约
### 1.1 anvil
1. 合约区别: 在 anvil 上需要提供 test 函数的测试能力, 增加了一个任何人都可以访问的 mint 函数
2. 部署命令: `forge script script/DeployEthanToken.s.sol:DeployEthanToken --private-key $PRIVATE_KEY --rpc-url $RPC_URL --broadcast`
3. 部署账户: anvil 账户0
4. 合约地址: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
5. **重要**: 上面的流程在单元测试 Raffle 的时候出现问题, 错误在于实现部署在 anvil 上的 EthanToken 合约在 test 中使用会报错. 于是改变了 Helper 脚本中构造 anvil 环境中 EthanToken 合约的逻辑, 现在改为**直接在 Helper 中 new 代币合约**.
6. 完成了目前的所有测试函数, 唯一的疑惑点就是: 执行最后一个测试时, requestId 和 randomNum 每一次都是一样的:
   1. 查看 mock 逻辑, 随机数是根据 requestId 和 请求数组下标组合哈希生成的, 那么只要这两个不变, 那随机数就不变.
   2. mock 逻辑和真正的链上逻辑是不一样的, mock 实现简单
7. 基于 6, 进一步探索了 vrfCoordinator 的实现逻辑, 真正的 vrfCoordinator 实现逻辑是很复杂的, 涉及与真正的随机数生成合约的交互(零知识证明), 也就是说, VRFCoordinatorV2_5 和 VRFCoordinatorV2_5Mock 合约不是同一个类型(其函数参数都不一样), 那为什么 Interactions.s.sol 在创建订阅时直接将 VRFCoordinatorV2_5 转换成了 VRFCoordinatorV2_5Mock 类型? 
   1. 那么这里就还是准备在实际部署到非本地链的时候, 手动设置好配置. 因为事实上 sepolia 和 mainnet 的 VRFCoordinator 都不一样. 不太好弄自动化
8. **除开上面的小插曲, 一切测试顺利! 也成功为 winner 铸造了 NFT!** 接下来考虑更加严谨的 mint 权限控制
   1. token: 写测试函数的时候, 是直接在脚本里 new 的, 但是实际部署的时候, 还是应该单独部署然后写进配置里. 因为需要同时给 merkleDrop 和 Raffle 两个合约转账. 
   2. nft: nft 合约就是由 raffle 创造的, 也理应只能由 Raffle 为 winner 铸造 NFT
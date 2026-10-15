# Snake（Godot 4.7 / 纯 GDScript）

保留单人、同屏双人、IP 直连联机、自定义 .map 地图及原有美术。打开 project.godot 运行主菜单。建房名称填写 **--server** 时保留原来的纯服务端模式。

## 职责与接口

    键盘 / 手柄 / TouchPad
              ↓ 方向意图
    Controller → 单机 GameScene / 联机 Net
                             ↓ 房主推进
                      MatchSimulation
                             ↓ 完整格子状态
                      Snake 视图 + HUD

- core/MatchSimulation 与 SnakeState 是 RefCounted 数据对象，无场景树、动画、摄像机依赖。入口为 configure()、start()、submit_direction()、step()、snapshot()。
- 单机与同屏模式由 GameScene 的固定步长时钟推进；联机只有房主的常驻 Net 推进，默认间隔仍为 0.5 / game_speed 秒。
- Snake 只呈现快照。一个循环驱动全部蛇节的插值与连接线，完成插值后停止逐帧更新。蛇节仅在长度变化时增减；穿边界走最近边缘，缺失中间步时直接校正。
- TouchPad 是 Control，每个方向盘捕获自己的手指。按下立即提交，滑入新方向再次提交；中心死区、方向滞回、取消与失焦清理均在此层处理，不生成合成的持续按下事件。
- 游戏动作使用 p1_* / p2_*，启动时从方向键 / WASD / 手柄绑定复制，两个手柄分别限制到设备 0、1；菜单的 ui_* 动作独立保留。

## 联机协议和生命周期

全部 RPC 固定在 /root/Net，协议中没有场景 NodePath 或任意属性更新。

客户端只连接房主，关闭 SceneMultiplayer 的客户端间中转；完整玩家名单由大厅协议维护。断线回调内先清理数据，广播延后到本轮 ENet 轮询完成，避免多个连接同时退出时向已关闭的通道发送。

| 通道 | 用途 | 传输 |
| --- | --- | --- |
| 0 | 大厅资料、地图、准备、加载确认、倒计时、初始与最终状态、返大厅 | reliable |
| 1 | 客户端转向意图 | reliable |
| 2 | 每个格子步的完整对局快照 | unreliable |

客户端只能提交自己的方向与资料；身份由 get_remote_sender_id() 获取。快照包含 round_id、tick、phase、step_seconds、蛇的编号/名称/颜色/身体/方向/死亡/分数、食物和胜者编号。旧局、旧步、重复快照和结算后的迟到运行快照会被忽略。客户端不自行计分、刷食物或判碰撞。

大厅设置变更清空准备状态。全部已连接参与端登记并准备后，房主冻结地图和玩家名单，禁止新连接；加载场景并确认就绪后，房主统一发出 3、2、1、Snake 倒计时，再开始模拟。30 秒没有全部就绪则取消开局并返回大厅。常驻会话缓存最新状态，视图订阅后主动读取。

对局中客户端断线，其蛇停止移动并保留为障碍；房主断线则清空会话并返回主菜单。任意参与者在结算页返回时，由房主协调所有端返回大厅。首版没有预测、回滚、重连、房主迁移或旧客户端协议兼容。

## 保持和明确的规则

- 所有蛇先计算下一身体，再统一判碰撞并提交。撞墙、自撞、撞蛇身死亡；同格撞头或迎面交换头位置双方死亡。
- 非增长蛇本步腾空的尾格可进入。死亡当步的移动（包括进入食物造成的增长）提交后，身体冻结为障碍，避免回滚尾格导致判定顺序不同。
- 每个移动间隔只保存最后一次方向意图，在执行时相对当前方向禁止反向，没有转向队列。
- 满盘时食物位置为 (-1, -1)，停止生成食物并继续移动，按死亡条件结束。
- 多人存活者优先获胜；全灭时最长者获胜，同长平局。
- .map 格式不变。导入先验证尺寸、格子内容与出生身体，失败保留原地图。分数显示配置统一使用 show_scores，读取时兼容旧 show_score。

## 自动检查

以下命令的 $Godot 指向 Godot 4.7.1 可执行文件。在项目根目录执行；日志、预览和测量写入被忽略的 .godot 目录。

    & $Godot --headless --path . --log-file .godot/tests.log res://tests/run_tests.tscn
    ./tests/run_network.ps1 -Godot $Godot -Scenario clean -Cycles 20
    ./tests/run_network.ps1 -Godot $Godot -Scenario fault -Cycles 5
    ./tests/run_network.ps1 -Godot $Godot -Scenario timeout -Cycles 2
    ./tests/run_network.ps1 -Godot $Godot -Scenario dedicated -Cycles 2
    ./tests/run_network.ps1 -Godot $Godot -Scenario disconnect -Cycles 1
    ./tests/run_network.ps1 -Godot $Godot -Scenario server_loss -Cycles 1
    & $Godot --headless --path . --log-file .godot/benchmark.log res://tests/benchmark.tscn

测试使用原生 GDScript，无第三方插件。网络测试占用本机 UDP 端口 25433–25435，失败连接测试使用 25439。网络场景创建房主与两个客户端进程，退出时清理自己创建的进程。不要同时运行两组网络测试。

有损代理在 ENet 下方注入 10% 概率丢包及每程 50–100ms 延迟抖动，也影响 ACK。测试逐份比较收到的运行快照和最终状态的哈希，并要求观察到快照跳步后重新收到正确运行状态。

### 本次验证（2026-10-16）

- 69 项规则、旧地图、设置、触屏事件、视图、场景及失败连接检查通过。
- 20 轮普通联机、5 轮有损联机、2 轮超时恢复后重开、2 轮纯服务端通过；客户端掉线及房主退出清理通过。
- 最终有损测试记录为接收 733 个 UDP 包、丢弃 63 个，观察到 10 次快照跳步后恢复；收到的运行快照与房主同一步一致。
- 多个客户端同时退出的回归连续通过 5 次；大厅广播延后到网络轮询完成，并关闭了本架构不需要的客户端间中转。
- 桌面 Forward+ 成功生成同屏双人预览，检查并修复了增长蛇尾从原点插入的问题。原有渲染器和 MSAA 设置未更改。
- 当前机器 headless CPU 压力样例（两条蛇共 1024 节、两个共享世界的子视口）：约 0.174ms / 规则步、0.005ms / 快照、2.0ms / 两条蛇视觉更新；快照约 8.7KB。这是调试运行的单机样本，不是帧率或移动端性能承诺，也没有与旧版做同场景耗时比较。

桌面可视预览可运行 tests/render_preview.tscn，输出 .godot/preview.png。Compatibility 出图时当前引擎提示不支持 2D MSAA，因此没有据此切换渲染器。测试环境还会报告无法读取 Windows 根证书库；本地 ENet 测试不依赖 TLS。

## 仍需真机验证

自动触屏事件覆盖多指、按下/滑动/抬手、中心抖动、边缘滞回、拖出再进入、取消和失焦；仍需要在 Android 确认实际触感、同屏双指、不同屏幕尺寸及应用切后台行为。移动端 GPU 耗时和耗电未测，暂不降低 MSAA 或切换渲染器。

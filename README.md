# Boot Viewer — Godot 4 程序化过膝长靴

参考图：黑色漆皮过膝长靴，正面金色拉链、金色细高跟、尖头。

整个模型**没有导入任何外部网格**，全部由 GDScript 在运行时生成：

- `boot_model.gd` — 几何生成
  - 脊柱（spine）为一串 3D 控制点，用 Catmull-Rom 采样成 120 圈
  - 截面为**超椭圆**（指数 2 = 椭圆，越大越方），沿脊柱扫掠（loft）
  - 用**平行传输**（parallel transport）计算每一圈的 binormal/normal，避免扭转
  - 脚部底面前低后高，形成高跟的拱形
  - 拉链：沿前中线的飘带 + MultiMesh 齿 + 拉头拉片
  - 鞋跟：金色锥体，顶部埋在靴筒内部，不露端盖
- `main.gd` — 场景、灯光、轨道相机、换色 UI

## 运行

需要 [Godot 4.7](https://godotengine.org/download/windows/)（免费，单文件 exe，不用安装）。用 Godot 打开本目录的 `project.godot`，按 F5。

- **左键拖动**：旋转视角
- **滚轮**：缩放
- **色块**：一键换皮革颜色（8 个预设）
- **自定义颜色…**：打开取色器，任意颜色
- **光泽滑块**：调皮革粗糙度（0.05 = 镜面漆皮，0.7 = 哑光）

换色只影响皮革，金色拉链和鞋跟保持金属材质。

## 改模型

`boot_model.gd` 顶部几组数组一一对应，改一个数就改一处造型：

| 数组 | 含义 |
| --- | --- |
| `_c_pos` | 脊柱控制点（Y 向上，+Z 是脚尖方向），共 16 个 |
| `_c_rx` | 该处截面的半宽（左右） |
| `_c_ry` | 该处截面的半深 / 半高 |
| `_c_sq` | 超椭圆指数：2 = 圆润的腿部，3.5+ = 方正的鞋底 |
| `_c_back` | 该处截面后侧向后拉出的距离（鞋跟座），当前为 0，可用来加鞋跟罩 |

索引 0 在大腿口，15 在脚尖。

## 导出成静态网格（可选）

如果想把生成的网格存成资源供别的场景用，加一段：

```gdscript
var mesh: ArrayMesh = boot.body.mesh
ResourceSaver.save(mesh, "res://boot_mesh.tres")
```

`boot.body` 是 `MeshInstance3D`，材质在 `boot.leather`。

## 许可

MIT License，见 [LICENSE](LICENSE)。

# Choicy-Whitelist

基于 roothide 版 Choicy 修改的插件注入管理工具，适用于 iOS 15–17 的 roothide 环境。

在原有功能基础上，将默认放行调整为默认禁用，通过手动启用的方式管理插件注入，并对注入规则提示和设置界面进行了调整。

## 主要修改

- 将应用程序、系统进程、隐藏应用和应用拓展的插件注入策略调整为默认禁用，保留必要系统组件及越狱安装应用的默认开启规则。
- 增加插件注入目标的匹配提示，通过颜色区分已启用状态及待手动启用的匹配条目。
- 移除原有插件故障排除及相关冲突排查功能。
- 调整设置面板的布局、分类和自定义插件配置界面。

注入匹配提示依据插件的注入规则及目标信息生成，供配置时参考，不代表插件已经实际加载；最终加载情况取决于插件自身的注入条件、当前配置及运行状态。

## 致谢

感谢 **opa334（Lars Fröder）** 开发并开源 Choicy，感谢 **roothide** 提供适配版本。本项目基于两者的工作进行修改。

- 原项目：[opa334/Choicy](https://github.com/opa334/Choicy)
- 基于的 Fork：[roothide/Choicy](https://github.com/roothide/Choicy)

## 许可证

本项目沿用 Choicy 的 **MIT License**，完整条款见 [LICENSE](LICENSE)。原作者的版权声明及许可声明予以保留；复制、修改或分发本项目时，请遵守许可证中保留相关声明的要求。软件按许可证约定以“现状”提供，不附带任何明示或默示担保。

- [AltList 许可证](external/AltList/LICENSE)
- [ChOma 许可证](external/ChOma/LICENSE)
- [litehook 许可证](external/litehook/LICENSE)

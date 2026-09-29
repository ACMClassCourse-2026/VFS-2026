# 虚拟文件系统（VFS）

## 作业目标

* 学会使用 STL 库
* 加深对于字符串处理的掌握
* 提高模拟水平，掌握基本的拆分功能、规划项目的能力
* 学会设计类型系统与类型检查规则
* 学会使用迭代器
* 规范代码风格，学会自己设计测试数据

## 背景

本作业要求实现一个**虚拟文件系统（VFS）**，模拟目录树、相对名字解析、文件类型系统，以及删除、查找、统计等文件操作。

在该文件系统中，目录（directory）可以包含子目录和文件，文件（file）保存具体的内容。不同的目录下可以存在同名文件，互不干扰。

当我们在某个目录中使用一个**相对名字**（例如 `x.txt`）时，名字沿**查找路径**解析：从当前目录开始，逐级向父目录回溯，直到根目录，找到的第一个匹配项即被使用。例如：

```
/           — 根目录
/x.txt      — 内容 "root"
/a/         — 子目录
/a/x.txt    — 内容 "inner"
/a/b/       — 子目录
/a/b/x.txt  — 内容 "deep"
```

当当前目录是 `/a` 时，`x.txt` 解析为 `/a/x.txt`；当当前目录是 `/` 时，解析为 `/x.txt`。子目录中的同名文件会**遮蔽**父目录中的同名文件，退出子目录后，父目录的同名文件又重新可见。

## 作业说明

### 分数组成

| 得分项 | 分数占比 |
| :---: | :---: |
| 前置作业 | 20% |
| VFS（主体） | 60% |
| Code Review | 20% |
| Bonus（额外加分） | 最多 +5% |

* 在 Code Review 中会严格审查代码风格，请遵循代码风格要求。
* 建议在本地保存自己设计过的测试数据，并记录遇到的问题与解决过程，Code Review 时会检查。
* Bonus 为额外加分，包含 `rmr` 和 `tree`，最多 +5%。

### 测试样例

* 测试分为主体和 Bonus 两部分，均下发部分样例（含输入与期望输出），供本地测试。
* 通过下发样例可获得相应部分 60% 的分数，通过隐藏测试点可获得剩余 40% 的分数。

### 概念

* **根目录** `/` 是文件系统的顶层目录，程序开始时的当前目录（`cwd`）就是根目录。
* 每个目录包含若干子目录与文件，**同一目录下不允许重名**（文件与目录共用名字空间）。
* **查找路径**：从当前目录开始，向父目录逐级回溯直到根目录。查找某个文件名时，在查找路径上逐级检查，**最近的匹配项优先**。
* **名字遮蔽**：子目录中的文件会遮蔽父目录中的同名文件。子目录内访问该名字时，得到的是子目录里的那个；退出子目录（`cd ..`）后，父目录的同名文件重新可见。
* **解析与类型检查分离**：名字解析只取查找路径上**最近的匹配项**，不会因类型不符而跳过它继续向父目录查找。若最近匹配项的类型不满足操作要求（是目录或 `bin` 等），直接输出 `Invalid operation`。例如，在 `/a` 下新建名为 `x.txt` 的目录以遮蔽根目录的同名文件：

```
create txt x.txt "root"
mkdir a
cd a
mkdir x.txt
cat x.txt      → Invalid operation   （最近匹配是目录，类型不符，不继续向上找）
cd ..
cat x.txt      → x.txt:root          （遮蔽解除，父目录的同名文件重新可见）
```
* `mkdir` / `create` / `rm` / `rmr` 只作用于**当前目录的直接子项**；`cd` 只进入当前目录的直接子目录。
* 各指令使用哪种名字解析方式，汇总如下：

| 解析方式 | 指令 |
| --- | --- |
| 只查找当前目录的**直接子项** | `mkdir` / `create` / `rm` / `rmr` / `cd` |
| 沿**查找路径**解析 | `cat` / `stat` / `append` / `concat` / `read` / `write` / `truncate` / `find` |

例如：当前目录 `/a` 下没有 `x.txt` 但根目录下有 `x.txt` 时，`cat x.txt` 能读到根目录的文件（沿查找路径找到）；而 `rm x.txt` 输出 `Invalid operation`（`/a` 下没有名为 `x.txt` 的直接子项）。

## 作业要求

模拟一个具备目录结构、类型系统与名字查找规则的文件系统。每条指令占一行。

### 指令总览

**必做指令**

| 指令 | 说明 |
| --- | --- |
| `mkdir [name]` | 在当前目录创建子目录 |
| `cd [name]` / `cd ..` | 进入子目录 / 返回父目录 |
| `create [type] [name] [content]` | 在当前目录创建文件 |
| `append [name] [content]` | 向文本文件追加内容 |
| `concat [result] [f1] [f2]` | 拼接两个文本文件 |
| `cat [name]` | 输出文件内容 |
| `ls` | 列出当前目录 |
| `rm [name]` | 删除当前目录下的文件或空目录 |
| `undo` / `redo` | 撤销 / 重做最近一次操作 |
| `read [name] [offset] [length]` | 读取 bin 文件的字节区间 |
| `write [name] [offset] [hexdata]` | 向 bin 文件写入字节 |
| `truncate [name] [size]` | 截断或扩展 bin 文件 |
| `top [k]` | 当前目录内大小最大的 k 个文件 |
| `find [name]` | 沿查找路径查找所有同名文件 |
| `stat [name]` | 输出指定名字（文件或目录）的类型与大小 |

**Bonus（选做）**

| 指令 | 说明 |
| --- | --- |
| `rmr [name]` | 递归删除（含非空目录） |
| `tree` | 以缩进树形式输出子树 |

其中 `[type]` 为 `txt`、`md`、`bin` 三者之一。

## 指令介绍

### `mkdir [name]`

在当前目录下创建一个子目录。

```
mkdir src
```

要求：

* 当前目录下已有同名项（文件或目录）时：`Invalid operation`。

### `cd [name]` / `cd ..`

* `cd [name]`：进入当前目录的**直接子目录** `[name]`。
* `cd ..`：返回父目录。

```
cd src
cd ..
```

要求：

* `cd ..` 时若当前目录是根目录（无父目录）：`Invalid operation`。
* `cd [name]` 时若 `[name]` 不是当前目录的直接子目录或是文件：`Invalid operation`。
* `cd` 只支持进入直接子目录，不支持绝对路径与跨级路径。

### `create [type] [name] [content]`

在当前目录下创建一个类型为 `[type]`、名为 `[name]` 的文件，内容为 `[content]`。

```
create txt main.cpp "int main()"
create md README.md "# title"
create bin data.bin "48 65 6C 6C 6F"
```

要求：

* 当前目录下已有同名项：`Invalid operation`（同名文件只允许出现在不同层级目录中）。
* `[content]` 是以 `"` 开头并以 `"` 结尾的字符串常量（见"名字与字符串规则"）。
* 三种类型都允许空内容：`create txt a.txt ""` 创建空文本文件。
* `[type]` 为 `bin` 时，`[content]` 为大写十六进制字节序列，需要解析为字节保存；空串 `""` 表示空文件（规则见"名字与字符串规则"）。

`txt` 与 `md` 是**文本文件**；`bin` 是**二进制文件**。三种文件的内部格式不同（见"文件格式"一节），但创建时统一以字符串常量形式接收内容。

### 文件格式

三种文件类型具有不同的内部格式：

* **`txt`（纯文本文件）**：内容以字符序列形式保存，是最基本的文本文件。
* **`md`（文档文件）**：内容同样是字符序列，但作为一种独立的文档类型存在，与 `txt` 是两种不同的类型（`stat` 中可区分）。
* **`bin`（二进制文件）**：内容以**字节序列**形式保存，与文本文件的保存方式不同。创建时传入的 `[content]` 为大写十六进制字节序列（见 `create`）；创建后可用 `read` / `write` / `truncate` 按字节操作。

类型系统规则：

* 文本操作（`append` / `concat` / `cat`）只接受文本文件（`txt` / `md`）；`bin` 参与时输出 `Invalid operation`。
* 三者 `size` 统一按内容字节数计算（`txt` / `md` 为字符串长度，`bin` 为字节序列长度）；目录固定为 `0`。
* 三种类型的区别通过 `stat` 输出的类型名体现。

### `append [name] [content]`

向文本文件追加内容，等价于 `content += [content]`。

```
create txt a.txt "hello"
append a.txt "world"
```

要求：

* `[name]` 在查找路径上可访问。
* `[name]` 必须是文本文件（`txt` / `md`）。是目录或 `bin` 时：`Invalid operation`。

### `concat [result] [f1] [f2]`

将两个文本文件拼接，结果写入 `result`，等价于 `result = f1 + f2`。

```
concat all.txt a.txt b.txt
```

要求：

* `result`、`f1`、`f2` 都必须在查找路径上可访问。
* 三者都必须是文本文件（`txt` / `md`）。任一为目录或 `bin` 时：`Invalid operation`。
* `result` 可以与 `f1` 或 `f2` 相同（例如 `concat a.txt a.txt b.txt`）：实现时应先读取 `f1`、`f2` 的内容，再写回 `result`。
* `result` 原有的内容被覆盖。

### `cat [name]`

输出文件的名字与内容。

```
cat a.txt
```

输出格式：`[name]:[content]`，例如 `a.txt:hello`。

要求：

* `[name]` 在查找路径上可访问。
* `[name]` 必须是文本文件。是目录或 `bin` 时：`Invalid operation`。

### `read [name] [offset] [length]`

读取 bin 文件从字节位置 `[offset]` 起的 `[length]` 个字节并输出。

```
read a.bin 10 20
```

输出格式：`[name]:[hex]`，`hex` 为大写、空格分隔的十六进制字节组，例如 `a.bin:01 02 03`。`[length]` 为 0 时输出 `[name]:`（冒号后无内容）。

要求：

* `[name]` 在查找路径上可访问，且必须是 `bin` 文件。是目录或文本文件时：`Invalid operation`。
* `[offset] + [length]` 不得超过文件大小，否则 `Invalid operation`。
* 越界检查对 `[length] = 0` 同样适用：`[offset]` 可以**等于**文件大小，但不能大于文件大小。
* `read` 不改变文件系统状态，不产生可撤销记录。

### `write [name] [offset] [hexdata]`

将 `[hexdata]` 表示的字节序列从字节位置 `[offset]` 起**覆盖**写入 bin 文件，不移动后续字节。

```
write a.bin 1 "FF FF"
```

例如原内容 `01 02 03 04`，执行 `write a.bin 1 "FF FF"` 后为 `01 FF FF 04`。

要求：

* `[name]` 在查找路径上可访问，且必须是 `bin` 文件。是目录或文本文件时：`Invalid operation`。
* `[hexdata]` 为非空的大写十六进制字节序列，以 `"` 开头并以 `"` 结尾的字符串常量形式给出（规则见"名字与字符串规则"）。
* `[offset] + [hexdata] 字节数` 可以超过文件末尾：超出部分**扩展文件**。`[offset]` 大于原文件大小时，原末尾到 `[offset]` 之间的空缺字节补 `0`。

### `truncate [name] [size]`

将 bin 文件的大小调整为 `[size]` 字节。

```
truncate a.bin 3
```

例如原内容 `01 02 03 04 05`，执行 `truncate a.bin 3` 后为 `01 02 03`。

要求：

* `[name]` 在查找路径上可访问，且必须是 `bin` 文件。是目录或文本文件时：`Invalid operation`。
* `[size]` 小于当前大小则删除末尾字节；大于当前大小则**扩展文件**，新增字节补 `0`。

### `ls`

列出当前目录下的所有直接子项，按名字字典序每行一个，目录项带 `/` 后缀。

```
ls
```

例如当前目录包含 `b.txt`、`a.txt` 与目录 `src`，输出：

```
a.txt
b.txt
src/
```

（按字典序：`a.txt` < `b.txt` < `src`，注意目录按不含 `/` 的名字参与排序。）

空目录无输出。`ls` 永远不会输出 `Invalid operation`。

### `rm [name]`

删除当前目录下的一个直接子项（文件或目录）。

```
rm a.txt
```

例如：

```
mkdir src
create txt note.txt "hi"
rm note.txt
rm src
```

要求：

* `[name]` 必须是当前目录的**直接子项**（只查当前目录，不沿查找路径查找），否则 `Invalid operation`。
* `[name]` 是文件时直接删除；是目录时目录必须为空，否则 `Invalid operation`。
* 删除后，父目录中的同名文件重新可见（遮蔽解除）。
* 成功的 `rm` 产生可撤销记录（见 `undo`）；被删除的文件/目录可被 `undo` 完整恢复。

### `top [k]`

输出当前目录内大小最大的 `k` 个文件。

```
top 3
```

输出格式：每行 `[name]:[size]`，按 `size` 降序排列；`size` 相同时按名字字典序排列。`size` 为内容字节数（`txt` / `md` 为字符串长度，`bin` 为字节序列长度）。

要求：

* 只统计当前目录的**直接子文件**（不含子目录、父目录内文件）。
* `k` 保证为正整数；`k` 大于文件总数时全部输出；空目录无输出。

### `find [name]`

沿查找路径（当前目录 → 父目录 → … → 根目录）逐级查找名为 `[name]` 的文件，**每一级的同名文件都输出**（不做最近优先截断）。

```
find x.txt
```

输出格式：每行一个完整路径 `/[所属文件夹]/[文件名]`（根目录下的文件为 `/[文件名]`）。输出顺序与查找顺序一致：**当前目录一级 → 父目录 → … → 根目录**（同一目录内名字唯一，因此每一级至多输出一行）。假设当前目录为 `/a/b`（目录树见"背景"一节），则：

```
find x.txt
/a/b/x.txt
/a/x.txt
/x.txt
```

要求：

* 名字为**精确匹配**，大小写敏感。
* 只匹配**文件**，不匹配目录。
* 整条查找路径上没有任何同名文件时，输出 `Null`（单独一行）。

### `stat [name]`

输出指定名字（文件或目录）的类型与大小。

```
stat a.txt
```

输出格式：`[name]:[type]:[size]`。`type` 为 `txt` / `md` / `bin` / `dir` 之一；`size` 为内容字节数（`bin` 按字节数计），目录的 `size` 固定为 `0`。`stat` 同样接受目录：例如 `src` 为目录时，`stat src` 输出 `src:dir:0`。

要求：

* `[name]` 在查找路径上可访问，否则 `Invalid operation`。

### `undo` / `redo`

`undo` 撤销最近一次成功执行的可撤销操作，使文件系统恢复到执行该操作之前的状态；`redo` 重做最近一次被 `undo` 撤销的操作。

```
undo
redo
```

要求：

* 可撤销操作包括 `mkdir` / `create` / `append` / `concat` / `cd` / `write` / `truncate` / `rm`；若实现了 `rmr`（Bonus），同样需要支持撤销。
* 只有成功执行的可撤销操作会产生记录。即使内容未变化（如 `append` 空串、`truncate` 到原大小），成功执行仍产生一条记录；查询操作与输出 `Invalid operation` 的操作不产生记录。
* 成功的 `undo` 将最近一条可撤销记录移入可重做记录；成功的 `redo` 将最近一条可重做记录移回可撤销记录。两条指令本身不额外产生操作记录，均可连续执行。
* 任何成功执行的可撤销操作都会清空可重做记录；查询操作与输出 `Invalid operation` 的操作不清空。
* 没有可撤销记录时 `undo` 输出 `Invalid operation`；没有可重做记录时 `redo` 输出 `Invalid operation`。

## 名字与字符串规则

本节定义输入的格式规则。**输入保证格式正确**，程序中不需要检查格式错误，但解析需要按这些规则进行（解析方法见 Tips）。

整个项目中，除 `tree` 输出的制图字符（见 Bonus 说明）外，所有输入与输出均为 ASCII 字符。

* **名字（name）**：非空，不含 `/`，不含空白字符（空格、制表符等），不含 `"`，不是 `.` 或 `..`，长度不超过 20 个字节（按字节计）。
* **字符串常量（content）**：以 `"` 开头并以 `"` 结尾，中间为任意内容（可含空格），不支持转义字符，中间不能出现 `"`。解析时取第一个 `"` 与最后一个 `"` 之间的内容。
* **十六进制字节序列（`bin` 的 content）**：由单个空格分隔的若干**两位十六进制数字**组成，仅含 `0-9`、`A-F`；不含小写字母与多余空格。`create` 允许空串（空文件）；`write` 的序列非空。
* **大小（size）**：文件为内容字节数；目录为 `0`。

## 输入格式

第一行一个整数 `n`，表示指令条数。之后共 `n` 行，每行一条指令。

保证：

* 指令的关键字必然合法（每行第一个单词必为上述指令之一），每行参数数量正确。
* 名字、字符串常量、十六进制字节序列均符合"名字与字符串规则"；`[type]` 必为 `txt` / `md` / `bin` 之一。
* `top` 的 `k` 为正整数；`read` / `write` / `truncate` 的数字参数为非负整数。

**输入格式保证正确**，不需要处理任何格式错误。

**不保证语义正确**：重复创建同名项、操作不存在的名字、类型不匹配、越界、目录非空、`undo` 无记录等均可能出现。

数据范围：`n <= 2e5`，目录嵌套深度小于 100，数字参数（`read` / `write` / `truncate` 的 `offset`、`length`、`size`，`top` 的 `k`）不超过 1e6。

## 输出格式

* `cat`：输出 `[name]:[content]`。
* `read`：输出 `[name]:[hex]`，`hex` 为大写、空格分隔的十六进制字节组。
* `stat`：输出 `[name]:[type]:[size]`。
* `top`：输出 `[name]:[size]`，`size` 降序、同 `size` 按名字字典序。
* `find`：输出完整路径，当前目录一级 → 根目录；无匹配输出 `Null`。
* `ls`：名字字典序，目录带 `/`。
* 任何语义上非法的操作：输出 `Invalid operation` 并换行。非法操作不影响程序继续执行。

### 完整示例

输入：

```
21
create txt x.txt "root"
mkdir a
cd a
create txt x.txt "inner"
create md note.md "note"
create bin b.bin "48 65 6C 6C 6F"
cat x.txt
find x.txt
find note.md
ls
top 1
stat x.txt
stat b.bin
read b.bin 0 5
cd ..
rm a
find x.txt
cat x.txt
cd a
undo
ls
```

输出：

```
x.txt:inner
/a/x.txt
/x.txt
/a/note.md
b.bin
note.md
x.txt
b.bin:5
x.txt:txt:5
b.bin:bin:5
b.bin:48 65 6C 6C 6F
Invalid operation
/x.txt
x.txt:root
a/
x.txt
```

## Tips

* 数据量达到 `2e5`，建议在 `main` 开头加上：

```cpp
std::ios::sync_with_stdio(false);
std::cin.tie(nullptr);
```

* 输入规模较大，注意避免不必要的线性查找。
* 建议合理设计目录树结构，并考虑名字解析效率。查找路径可以通过保存父节点关系或路径信息实现。
* 可能用到的头文件的一部分：

```
<map>
<unordered_map>
<set>
<vector>
<stack>
<queue>
<deque>
<utility>
<optional>
<tuple>
<variant>
<algorithm>
```

## Bonus 说明

* `rmr [name]`：删除当前目录下的直接子项。文件直接删除；目录**递归删除**（连同其整棵子树）。只查当前目录直接子项，否则 `Invalid operation`。
* `tree`：从当前目录开始，以缩进树形式输出整棵子树。
  - 首行为当前目录名（路径最后一段）加 `/`（根目录为 `/`），空目录也输出首行。
  - 每行一个节点；同一目录下按名字字典序排列（目录按不含 `/` 的名字参与排序，与 `ls` 一致），目录带 `/`。
  - 所有子项都输出，包括以 `.` 开头的名字。
  - 缩进使用 UTF-8 制图字符：非最后一项前缀 `├── `，最后一项前缀 `└── `；进入子目录后，其子项前缀分别延续 `│   ` 与 `    `（四个空格）。
  - 输出文件须为 UTF-8 编码；制图字符的具体写法请自行查阅相关文档（不要直接从本文件复制粘贴），Code Review 时会检查。

完整示例（执行到 `tree` 时当前目录为 `/a`）：

输入：

```
mkdir a
cd a
create txt f1.txt "hello"
mkdir b
cd b
create txt f2.txt "hi"
cd ..
create txt f3.txt "world"
tree
```

输出：

```
a/
├── b/
│   └── f2.txt
├── f1.txt
└── f3.txt
```

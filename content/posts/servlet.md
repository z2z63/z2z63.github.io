---
title: "WebServer、Servlet与二段式构造"
author: z2z63
date: 2025-07-16T00:12:04+08:00
---

提到 servlet 我总是想起 applet、JSP，因为现在学校还在教这种老古董。但在最近学习 spring 的过程中我发现 spring 往下就是 servlet。因此记录一下学习 servlet 中的一些思考  

## 从最简单的 WebServer 到 Servlet

如果要实现一个最简单的 WebServer，他应该由哪些部分组成？大二时我给出的方案是三个类: `WebServer`,`HttpRequest`,`HttpResponse`（再加上一个可选的模板类 `ThreadPool`)，其中关键数据结构如下

```cpp
class HttpRequest { 
public: 
    std::string path; 
    std::string method; 
    std::map<std::string, std::string> headers; 
}; 

class HttpResponse { 
public:
    std::map<std::string, std::string> headers;
    std::vector<byte> body; 
    int code; 
};
```

这样设计的 WebServer 非常简洁优雅

```cpp
#include "WebServer.h"

// 请求 /template 返回渲染后的 HTML 
HttpResponse templateHandler(HttpRequest &request) { 
    mstch::map data; 
    data["time"] = std::string("111"); 
    return HttpResponse().render("template.html", data); 
} 

int main() { 
    // 读取配置 
    YAML::Node config = YAML::LoadFile("config.yaml"); 
    int port = config["port"].as<int>(); 
    auto staticPath = config["staticFilePath"].as<std::string>(); 
    auto templatePath = config["templateFilePath"].as<std::string>(); 
    int poolSize = config["threadPoolSize"].as<int>(); 
    
    // 启动 WebServer，设置路由 
    WebServer server(poolSize); 
    server.bind(port).setStaticFilePath(staticPath).setTemplateFilePath(templatePath) 
        .route("/template", templateHandler).run(); 
    return 0; 
}
```

以上可以看出一个 WebServer，或者更准确的说，HTTP Server 最核心的只有三个部分，一是 Server 本体，二和三是 HTTP 请求对象和响应对象，HTTP 请求对象只需包括最关键的四个字段：方法、请求路径、HTTP 头部和 HTTP 主体，其中 HTTP Server 最感兴趣的就是请求方法和请求路径，因为这决定了如何路由这个 HTTP 请求。而 HTTP 响应只需包括最关键的两个字段：HTTP 头部和 HTTP 主体  

当然一个 HTTP Server 还需要考虑很多细节，比如缓存控制、内存管理、epoll  IO 多路复用、HTTP2 支持、HTTP3 支持、HTTPS 支持等等。但即使加上了这么多功能，这样的一个 HTTP Server 使用起来还是太原始了，因为任何额外的功能都需要开发者根据 HTTP 协议规范设置 HTTP header，组装 HTTP body。

有了以上知识后，Servlet 就能轻松理解，其核心 `Servlet` 接口

```java
public interface Servlet {

    void init(ServletConfig config) throws ServletException; 
    
    void service(ServletRequest req, ServletResponse res) throws ServletException, IOException; 
    
    void destroy(); 
    
    // 省略... 
}
```

其中`init`和`destroy`分别表示 servlet 的生命期开始与结束，`service`表示其功能：根据 http 请求返回相应的 http 响应，即在某个 http 端点提供 http 服务。这一个简单的接口表示了一个 HTTP Server 的核心

1. Server 本体（`ServletConfig#getServletContext`可获得`ServletContext`，其内部封装了 Servlet 容器提供的一系列能力）
2. HTTP 响应 （`ServletRequest`）
3. HTTP 响应（`ServletResponse`）

Servlet 提供的其他功能，都可以看作是解决“HTTP Server 使用起来太过原始”的缺点，例如 cookie 、session、filter 等等

## 二段式构造

所谓二段式构造，就是通过`open/close`或`init/deinit`或`create/destory`方法，在对象生命期之上由增加了人为定义的生命期，对象在 constructor 调用之后、init 之前语义上是合法的，人为定义却又是非法的，同理 deinit 之后、引用计数降为零之前语义上是合法的，人为定义又是非法的。
C++许多历史项目大量运用了二段式构造，其优点是绕过了 constructor 不能返回状态码的问题、可以在未申请资源之前完成对象初始化、主动控制资源申请时机。如果一个对象在其生命期需要持有资源，那么在它生命期开始时就应当申请到资源，但申请资源是可能失败的，打开文件、打开网络套接字、建立线程，严谨的来说任何系统调用都可能失败，失败后就应当报告给上层，有两种报告方式，其一是返回状态码，其二是抛出异常。但 constructor 不能返回状态码，而在 constructor 抛出异常虽然可行，由于各种原因（历史、项目约定、异常规格对 STL 不友好、第三方库必须禁用异常），往往不会在 constructor 中抛出异常，所以往往使用二段式构造
> [!Note]
> 还有一个绕过「constructor 不能返回状态码」的方法：constructor 额外传入一个 `int`，如果构造成功，这个 `int` 赋值为 `0`，否则赋值为错误码，但这个方法也并不比二段式构造好多少

二段式构造有什么问题呢？第一点肯定是不够优雅，向外暴露出了未定义行为（没有 `init` 就拿来用，会怎么样？谁都不知道），第二点是增加了心智负担，最好的文档就是充分利用语言特性禁止错误的、不推荐的、非最佳实践的用法，而不是写大段文档试图教会别人什么是正确的用法

在 C++ 中，针对二段式构造的缺点有一个方案可以几乎完美的解决

```cpp
class VectorDataManager{ 
private: 
    explicit VectorDataManager(int fd, PageId max_page_id); 
    
public: 
    static std::unique_ptr<VectorDataManager> create(const Table *table);
    
    ~VectorDataManager(); 

private: 
    // 省略... 
};
```

使用时

```cpp
std::uniqie_ptr<VectorDataManager> mgr = VectorDataManager::create(table); 
if(mgr == nullptr){ 
    // 处理错误...
    return -1; 
} 
// 正常逻辑
```

关键点：

1. constructor 私有，禁止外部构造，内部不包括资源申请，一定成功
2. `create`公开静态成员函数，内部尝试申请资源，申请资源失败则返回空指针，申请成功则构造（智能指针包裹的）对象并返回
3. `create`是外部唯一用于获取该对象的方法，使用者必须判空，可以使用`std::optional`强制使用者检查

这个方案还有一个问题，无法返回错误码表示各种错误原因，只需将错误码的引用作为参数传递进`create`就能解决。

当然，rust 的`std::Result`作为返回值也是非常好的解决方法

```rust
enum Result<T, E> { 
    Ok(T),
    Err(E), 
}
```

> 补充：C++23 也有和 rust 的`std::Result`相似的`std::expected`了！

### 二段式构造之于 java

以上提到的方案不能套用到 java，因为这个方案利用对象的生命期管理资源的申请与释放（RAII），因为在 C++中，对象的生命期是完全确定的。但 GC 语言的对象回收时机不确定，往往都不会提供 destructor，就算提供了 destructor，因为析构时机不确定，也难以使用。因此在 java 中无论如何都至少会有一个`close/deinit/destory`，很难完全消除二段式构造

## Servlet 与 Spring

- servlet：一小段运行在 Web Server 中的 java 程序，用于接受并响应 HTTP 请求
- Jakarta Servlet: 定义了用于处理并响应 HTTP 请求的服务器端 API
- `jakarta.servlet`: 来源于`jakarta.servlet:jakarta.servlet-api:<version>.jar`
- tomcat：实现了 Jakarta Servlet 的 HTTP Server
- spring 与 servlet：spring web application 包含两个技术栈，其一是 servlet(Spring Web Mvc)，其二是 reactive stream(Spring WebFlux)
- spring 与 tomcat：spring 可以使用内置的诸如 tomcat 这类实现了 Jakarta Servlet 的 HTTP Server

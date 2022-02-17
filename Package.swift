// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "xml",
    products: [.library(name: "xml", targets: ["XML"])],
    targets: [.target(name: "XML")]
)

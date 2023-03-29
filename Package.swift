// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "XML",
    products: [
        .library(name: "XML", targets: ["XML"]),
    ],
    targets: [
        .target(name: "XML"),
    ]
)

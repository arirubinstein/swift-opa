import AST
import Benchmark
import Foundation
internal import Rego

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration.timeUnits = .nanoseconds
    if let durationStr = ProcessInfo.processInfo.environment["BENCHMARK_MAX_DURATION_SECONDS"],
        let duration = Int(durationStr)
    {
        Benchmark.defaultConfiguration.maxDuration = .seconds(duration)
    }

    // Benchmark runs from the Benchmarks directory, so paths are relative to parent
    let bundleBase = "../Tests/RegoTests/TestData/Bundles"

    func regoBenchmark(
        _ name: String,
        bundleDir: String,
        bundleName: String,
        query: String,
        input: AST.RegoValue
    ) {
        Benchmark(
            name,
            configuration: .init(metrics: [.wallClock, .mallocCountTotal])
        ) { benchmark in
            var engine = OPA.Engine(
                bundlePaths: [
                    OPA.Engine.BundlePath(
                        name: bundleName,
                        url: URL(fileURLWithPath: "\(bundleBase)/\(bundleDir)"))
                ])
            var preparedQuery: OPA.Engine.PreparedQuery?
            do {
                preparedQuery = try await engine.prepareForEvaluation(query: query)
            } catch {}

            benchmark.startMeasurement()
            for _ in benchmark.scaledIterations {
                do {
                    let result = try await preparedQuery?.evaluate(input: input)
                    blackHole(result)
                } catch {}
            }
            benchmark.stopMeasurement()
        }
    }

    regoBenchmark(
        "Simple Policy Evaluation",
        bundleDir: "simple-directory-bundle",
        bundleName: "simple",
        query: "data.app.rbac.allow",
        input: [
            "user": "alice",
            "action": "read",
            "resource": "document123",
        ]
    )

    regoBenchmark(
        "Dynamic Call - Double",
        bundleDir: "dynamic-call-bundle",
        bundleName: "dynamic",
        query: "data.test",
        input: [
            "operation": "double",
            "value": 42,
        ]
    )

    regoBenchmark(
        "Dynamic Call - Square",
        bundleDir: "dynamic-call-bundle",
        bundleName: "dynamic",
        query: "data.test",
        input: [
            "operation": "square",
            "value": 42,
        ]
    )

    regoBenchmark(
        "Array Iteration - Small (10 items)",
        bundleDir: "array-iteration-bundle",
        bundleName: "iteration",
        query: "data.benchmark.iteration",
        input: [
            "items": .array((1...10).map { .number(RegoNumber(int: Int64($0))) }),
            "threshold": 5,
        ]
    )

    regoBenchmark(
        "Array Iteration - Medium (100 items)",
        bundleDir: "array-iteration-bundle",
        bundleName: "iteration",
        query: "data.benchmark.iteration",
        input: [
            "items": .array((1...100).map { .number(RegoNumber(int: Int64($0))) }),
            "threshold": 50,
        ]
    )

    regoBenchmark(
        "Array Iteration - Large (1000 items)",
        bundleDir: "array-iteration-bundle",
        bundleName: "iteration",
        query: "data.benchmark.iteration",
        input: [
            "items": .array((1...1000).map { .number(RegoNumber(int: Int64($0))) }),
            "threshold": 500,
        ]
    )

    regoBenchmark(
        "Numeric Literals",
        bundleDir: "numeric-literals-bundle",
        bundleName: "numeric",
        query: "data.benchmark.numeric",
        input: [
            "value": 10,
            "bonus": 5.5,
            "multiplier": 2.0,
        ]
    )

    let scanInput: AST.RegoValue = ["value": "/bin/nomatch"]

    regoBenchmark(
        "Build Literal Array (10 appends)",
        bundleDir: "array-build-bundle",
        bundleName: "array",
        query: "data.benchmark.array.matched",
        input: scanInput
    )

    let collectionInput: AST.RegoValue = ["value": "__nomatch__"]

    regoBenchmark(
        "Build Literal Object (10 inserts)",
        bundleDir: "object-build-bundle",
        bundleName: "object",
        query: "data.benchmark.object.matched",
        input: collectionInput
    )

    regoBenchmark(
        "Build Literal Set (10 adds)",
        bundleDir: "set-build-bundle",
        bundleName: "set",
        query: "data.benchmark.set.matched",
        input: collectionInput
    )
}

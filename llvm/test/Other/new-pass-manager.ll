; This test is essentially doing very basic things with the opt tool and the
; new pass manager pipeline. It will be used to flesh out the feature
; completeness of the opt tool when the new pass manager is engaged. The tests
; may not be useful once it becomes the default or may get spread out into other
; files, but for now this is just going to step the new process through its
; paces.

; RUN: opt -disable-output -disable-verify -debug-pass-manager \
; RUN:     -passes=no-op-module %s 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-MODULE-PASS
; CHECK-MODULE-PASS: Starting Module pass manager run
; CHECK-MODULE-PASS-NEXT: Running pass: NoOpModulePass
; CHECK-MODULE-PASS-NEXT: Finished Module pass manager run

; RUN: opt -disable-output -disable-verify -debug-pass-manager \
; RUN:     -passes=no-op-cgscc %s 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-CGSCC-PASS
; RUN: opt -disable-output -disable-verify -debug-pass-manager \
; RUN:     -passes='cgscc(no-op-cgscc)' %s 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-CGSCC-PASS
; CHECK-CGSCC-PASS: Starting Module pass manager run
; CHECK-CGSCC-PASS-NEXT: Running pass: ModuleToPostOrderCGSCCPassAdaptor
; CHECK-CGSCC-PASS-NEXT: Running analysis: InnerAnalysisManagerProxy<{{.*(CGSCCAnalysisManager|AnalysisManager<.*LazyCallGraph::SCC.*>).*}},{{.*}}Module>
; CHECK-CGSCC-PASS-NEXT: Running analysis: InnerAnalysisManagerProxy<{{.*(FunctionAnalysisManager|AnalysisManager<.*Function.*>).*}},{{.*}}Module>
; CHECK-CGSCC-PASS-NEXT: Running analysis: LazyCallGraphAnalysis
; CHECK-CGSCC-PASS-NEXT: Running analysis: TargetLibraryAnalysis
; CHECK-CGSCC-PASS-NEXT: Running analysis: PassInstrumentationAnalysis
; CHECK-CGSCC-PASS-NEXT: Running analysis: FunctionAnalysisManagerCGSCCProxy
; CHECK-CGSCC-PASS-NEXT: Running analysis: PassInstrumentationAnalysis
; CHECK-CGSCC-PASS-NEXT: Running analysis: OuterAnalysisManagerProxy<{{.*}}LazyCallGraph::SCC{{.*}}>
; CHECK-CGSCC-PASS-NEXT: Starting CGSCC pass manager run
; CHECK-CGSCC-PASS-NEXT: Running pass: NoOpCGSCCPass
; CHECK-CGSCC-PASS-NEXT: Finished CGSCC pass manager run
; CHECK-CGSCC-PASS-NEXT: Finished Module pass manager run

; RUN: opt -disable-output -disable-verify -debug-pass-manager \
; RUN:     -passes=no-op-function %s 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-FUNCTION-PASS
; RUN: opt -disable-output -disable-verify -debug-pass-manager \
; RUN:     -passes='function(no-op-function)' %s 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-FUNCTION-PASS
; CHECK-FUNCTION-PASS: Starting Module pass manager run
; CHECK-FUNCTION-PASS-NEXT: Running pass: ModuleToFunctionPassAdaptor
; CHECK-FUNCTION-PASS-NEXT: Running analysis: InnerAnalysisManagerProxy<{{.*}}>
; CHECK-FUNCTION-PASS-NEXT: Running analysis: PassInstrumentationAnalysis
; CHECK-FUNCTION-PASS-NEXT: Starting Function pass manager run
; CHECK-FUNCTION-PASS-NEXT: Running pass: NoOpFunctionPass
; CHECK-FUNCTION-PASS-NEXT: Finished Function pass manager run
; CHECK-FUNCTION-PASS-NEXT: Finished Module pass manager run

; RUN: opt -disable-output -debug-pass-manager -passes=print %s 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-MODULE-PRINT
; CHECK-MODULE-PRINT: Starting Module pass manager run
; CHECK-MODULE-PRINT: Running pass: VerifierPass
; CHECK-MODULE-PRINT: Running pass: PrintModulePass
; CHECK-MODULE-PRINT: ModuleID
; CHECK-MODULE-PRINT: define void @foo(i1 %x, i8* %p1, i8* %p2)
; CHECK-MODULE-PRINT: Running pass: VerifierPass
; CHECK-MODULE-PRINT: Finished Module pass manager run

; RUN: opt -disable-output -debug-pass-manager -disable-verify -passes='print,verify' %s 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-MODULE-VERIFY
; CHECK-MODULE-VERIFY: Starting Module pass manager run
; CHECK-MODULE-VERIFY: Running pass: PrintModulePass
; CHECK-MODULE-VERIFY: ModuleID
; CHECK-MODULE-VERIFY: define void @foo(i1 %x, i8* %p1, i8* %p2)
; CHECK-MODULE-VERIFY: Running pass: VerifierPass
; CHECK-MODULE-VERIFY: Finished Module pass manager run

; RUN: opt -disable-output -debug-pass-manager -passes='function(print)' %s 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-FUNCTION-PRINT
; CHECK-FUNCTION-PRINT: Starting Module pass manager run
; CHECK-FUNCTION-PRINT: Running pass: VerifierPass
; CHECK-FUNCTION-PRINT: Running pass: ModuleToFunctionPassAdaptor
; CHECK-FUNCTION-PRINT: Running analysis: InnerAnalysisManagerProxy<{{.*}}>
; CHECK-FUNCTION-PRINT: Starting Function pass manager run
; CHECK-FUNCTION-PRINT: Running pass: PrintFunctionPass
; CHECK-FUNCTION-PRINT-NOT: ModuleID
; CHECK-FUNCTION-PRINT: define void @foo(i1 %x, i8* %p1, i8* %p2)
; CHECK-FUNCTION-PRINT: Finished Function pass manager run
; CHECK-FUNCTION-PRINT: Running pass: VerifierPass
; CHECK-FUNCTION-PRINT: Finished Module pass manager run

; RUN: opt -disable-output -debug-pass-manager -disable-verify -passes='function(print,verify)' %s 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-FUNCTION-VERIFY
; CHECK-FUNCTION-VERIFY: Starting Module pass manager run
; CHECK-FUNCTION-VERIFY: Starting Function pass manager run
; CHECK-FUNCTION-VERIFY: Running pass: PrintFunctionPass
; CHECK-FUNCTION-VERIFY-NOT: ModuleID
; CHECK-FUNCTION-VERIFY: define void @foo(i1 %x, i8* %p1, i8* %p2)
; CHECK-FUNCTION-VERIFY: Running pass: VerifierPass
; CHECK-FUNCTION-VERIFY: Finished Function pass manager run
; CHECK-FUNCTION-VERIFY: Finished Module pass manager run

; RUN: opt -S -o - -passes='no-op-module,no-op-module' %s \
; RUN:     | FileCheck %s --check-prefix=CHECK-NOOP
; CHECK-NOOP: define void @foo(i1 %x, i8* %p1, i8* %p2) {
; CHECK-NOOP: entry:
; CHECK-NOOP:   store i8 42, i8* %p1
; CHECK-NOOP:   br i1 %x, label %loop, label %exit
; CHECK-NOOP: loop:
; CHECK-NOOP:   %tmp1 = load i8, i8* %p2
; CHECK-NOOP:   br label %loop
; CHECK-NOOP: exit:
; CHECK-NOOP:   ret void
; CHECK-NOOP: }

; Round trip through bitcode.
; RUN: opt -f -o - -passes='no-op-module,no-op-module' %s \
; RUN:     | llvm-dis \
; RUN:     | FileCheck %s --check-prefix=CHECK-NOOP

; RUN: opt -disable-output -debug-pass-manager -verify-each -passes='no-op-module,function(no-op-function)' %s 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-VERIFY-EACH
; CHECK-VERIFY-EACH: Starting Module pass manager run
; CHECK-VERIFY-EACH: Running pass: VerifierPass
; CHECK-VERIFY-EACH: Running pass: NoOpModulePass
; CHECK-VERIFY-EACH: Running pass: VerifierPass
; CHECK-VERIFY-EACH: Starting Function pass manager run
; CHECK-VERIFY-EACH: Running pass: NoOpFunctionPass
; CHECK-VERIFY-EACH: Running pass: VerifierPass
; CHECK-VERIFY-EACH: Finished Function pass manager run
; CHECK-VERIFY-EACH: Running pass: VerifierPass
; CHECK-VERIFY-EACH: Finished Module pass manager run

; RUN: opt -disable-output -debug-pass-manager -disable-verify -passes='no-op-module,function(no-op-function)' %s 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-NO-VERIFY
; CHECK-NO-VERIFY: Starting Module pass manager run
; CHECK-NO-VERIFY-NOT: VerifierPass
; CHECK-NO-VERIFY: Running pass: NoOpModulePass
; CHECK-NO-VERIFY-NOT: VerifierPass
; CHECK-NO-VERIFY: Starting Function pass manager run
; CHECK-NO-VERIFY: Running pass: NoOpFunctionPass
; CHECK-NO-VERIFY-NOT: VerifierPass
; CHECK-NO-VERIFY: Finished Function pass manager run
; CHECK-NO-VERIFY-NOT: VerifierPass
; CHECK-NO-VERIFY: Finished Module pass manager run

; RUN: opt -disable-output -debug-pass-manager \
; RUN:     -passes='require<no-op-module>,cgscc(require<no-op-cgscc>,function(require<no-op-function>))' %s 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-ANALYSES
; CHECK-ANALYSES: Starting Module pass manager run
; CHECK-ANALYSES: Running pass: RequireAnalysisPass
; CHECK-ANALYSES: Running analysis: NoOpModuleAnalysis
; CHECK-ANALYSES: Starting CGSCC pass manager run
; CHECK-ANALYSES: Running pass: RequireAnalysisPass
; CHECK-ANALYSES: Running analysis: NoOpCGSCCAnalysis
; CHECK-ANALYSES: Starting Function pass manager run
; CHECK-ANALYSES: Running pass: RequireAnalysisPass
; CHECK-ANALYSES: Running analysis: NoOpFunctionAnalysis

; Make sure no-op passes that preserve all analyses don't even try to do any
; analysis invalidation.
; RUN: opt -disable-output -debug-pass-manager \
; RUN:     -passes='require<no-op-module>,cgscc(require<no-op-cgscc>,function(require<no-op-function>))' %s 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-NO-OP-INVALIDATION
; CHECK-NO-OP-INVALIDATION: Starting Module pass manager run
; CHECK-NO-OP-INVALIDATION-NOT: Invalidating all non-preserved analyses

; RUN: opt -disable-output -debug-pass-manager \
; RUN:     -passes='require<no-op-module>,require<no-op-module>,require<no-op-module>' %s 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-DO-CACHE-MODULE-ANALYSIS-RESULTS
; CHECK-DO-CACHE-MODULE-ANALYSIS-RESULTS: Starting Module pass manager run
; CHECK-DO-CACHE-MODULE-ANALYSIS-RESULTS: Running pass: RequireAnalysisPass
; CHECK-DO-CACHE-MODULE-ANALYSIS-RESULTS: Running analysis: NoOpModuleAnalysis
; CHECK-DO-CACHE-MODULE-ANALYSIS-RESULTS-NOT: Running analysis: NoOpModuleAnalysis

; RUN: opt -disable-output -debug-pass-manager \
; RUN:     -passes='require<no-op-module>,invalidate<no-op-module>,require<no-op-module>' %s 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-DO-INVALIDATE-MODULE-ANALYSIS-RESULTS
; CHECK-DO-INVALIDATE-MODULE-ANALYSIS-RESULTS: Starting Module pass manager run
; CHECK-DO-INVALIDATE-MODULE-ANALYSIS-RESULTS: Running pass: RequireAnalysisPass
; CHECK-DO-INVALIDATE-MODULE-ANALYSIS-RESULTS: Running analysis: NoOpModuleAnalysis
; CHECK-DO-INVALIDATE-MODULE-ANALYSIS-RESULTS: Invalidating analysis: NoOpModuleAnalysis
; CHECK-DO-INVALIDATE-MODULE-ANALYSIS-RESULTS: Running analysis: NoOpModuleAnalysis

; RUN: opt -disable-output -debug-pass-manager \
; RUN:     -passes='cgscc(require<no-op-cgscc>,require<no-op-cgscc>,require<no-op-cgscc>)' %s 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-DO-CACHE-CGSCC-ANALYSIS-RESULTS
; CHECK-DO-CACHE-CGSCC-ANALYSIS-RESULTS: Starting Module pass manager run
; CHECK-DO-CACHE-CGSCC-ANALYSIS-RESULTS: Running pass: RequireAnalysisPass
; CHECK-DO-CACHE-CGSCC-ANALYSIS-RESULTS: Running analysis: NoOpCGSCCAnalysis
; CHECK-DO-CACHE-CGSCC-ANALYSIS-RESULTS-NOT: Running analysis: NoOpCGSCCAnalysis

; RUN: opt -disable-output -debug-pass-manager \
; RUN:     -passes='cgscc(require<no-op-cgscc>,invalidate<no-op-cgscc>,require<no-op-cgscc>)' %s 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-DO-INVALIDATE-CGSCC-ANALYSIS-RESULTS
; CHECK-DO-INVALIDATE-CGSCC-ANALYSIS-RESULTS: Starting Module pass manager run
; CHECK-DO-INVALIDATE-CGSCC-ANALYSIS-RESULTS: Running pass: RequireAnalysisPass
; CHECK-DO-INVALIDATE-CGSCC-ANALYSIS-RESULTS: Running analysis: NoOpCGSCCAnalysis
; CHECK-DO-INVALIDATE-CGSCC-ANALYSIS-RESULTS: Invalidating analysis: NoOpCGSCCAnalysis
; CHECK-DO-INVALIDATE-CGSCC-ANALYSIS-RESULTS: Running analysis: NoOpCGSCCAnalysis

; RUN: opt -disable-output -debug-pass-manager \
; RUN:     -passes='function(require<no-op-function>,require<no-op-function>,require<no-op-function>)' %s 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-DO-CACHE-FUNCTION-ANALYSIS-RESULTS
; CHECK-DO-CACHE-FUNCTION-ANALYSIS-RESULTS: Starting Module pass manager run
; CHECK-DO-CACHE-FUNCTION-ANALYSIS-RESULTS: Running pass: RequireAnalysisPass
; CHECK-DO-CACHE-FUNCTION-ANALYSIS-RESULTS: Running analysis: NoOpFunctionAnalysis
; CHECK-DO-CACHE-FUNCTION-ANALYSIS-RESULTS-NOT: Running analysis: NoOpFunctionAnalysis

; RUN: opt -disable-output -debug-pass-manager \
; RUN:     -passes='function(require<no-op-function>,invalidate<no-op-function>,require<no-op-function>)' %s 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-DO-INVALIDATE-FUNCTION-ANALYSIS-RESULTS
; CHECK-DO-INVALIDATE-FUNCTION-ANALYSIS-RESULTS: Starting Module pass manager run
; CHECK-DO-INVALIDATE-FUNCTION-ANALYSIS-RESULTS: Running pass: RequireAnalysisPass
; CHECK-DO-INVALIDATE-FUNCTION-ANALYSIS-RESULTS: Running analysis: NoOpFunctionAnalysis
; CHECK-DO-INVALIDATE-FUNCTION-ANALYSIS-RESULTS: Invalidating analysis: NoOpFunctionAnalysis
; CHECK-DO-INVALIDATE-FUNCTION-ANALYSIS-RESULTS: Running analysis: NoOpFunctionAnalysis

; RUN: opt -disable-output -disable-verify -debug-pass-manager \
; RUN:     -passes='require<no-op-module>,module(require<no-op-module>,function(require<no-op-function>,invalidate<all>,require<no-op-function>),require<no-op-module>),require<no-op-module>' %s 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-INVALIDATE-ALL
; CHECK-INVALIDATE-ALL: Starting Module pass manager run
; CHECK-INVALIDATE-ALL: Running pass: RequireAnalysisPass
; CHECK-INVALIDATE-ALL: Running analysis: NoOpModuleAnalysis
; CHECK-INVALIDATE-ALL: Starting Module pass manager run
; CHECK-INVALIDATE-ALL: Running pass: RequireAnalysisPass
; CHECK-INVALIDATE-ALL-NOT: Running analysis: NoOpModuleAnalysis
; CHECK-INVALIDATE-ALL: Starting Function pass manager run
; CHECK-INVALIDATE-ALL: Running pass: RequireAnalysisPass
; CHECK-INVALIDATE-ALL: Running analysis: NoOpFunctionAnalysis
; CHECK-INVALIDATE-ALL: Running pass: InvalidateAllAnalysesPass
; CHECK-INVALIDATE-ALL: Invalidating analysis: NoOpFunctionAnalysis
; CHECK-INVALIDATE-ALL: Running pass: RequireAnalysisPass
; CHECK-INVALIDATE-ALL: Running analysis: NoOpFunctionAnalysis
; CHECK-INVALIDATE-ALL: Finished Function pass manager run
; CHECK-INVALIDATE-ALL: Invalidating analysis: NoOpModuleAnalysis
; CHECK-INVALIDATE-ALL: Running pass: RequireAnalysisPass
; CHECK-INVALIDATE-ALL: Running analysis: NoOpModuleAnalysis
; CHECK-INVALIDATE-ALL: Finished Module pass manager run
; CHECK-INVALIDATE-ALL-NOT: Invalidating analysis: NoOpModuleAnalysis
; CHECK-INVALIDATE-ALL: Running pass: RequireAnalysisPass
; CHECK-INVALIDATE-ALL-NOT: Running analysis: NoOpModuleAnalysis
; CHECK-INVALIDATE-ALL: Finished Module pass manager run

; RUN: opt -disable-output -disable-verify -debug-pass-manager \
; RUN:     -passes='require<no-op-module>,module(require<no-op-module>,cgscc(require<no-op-cgscc>,function(require<no-op-function>,invalidate<all>,require<no-op-function>),require<no-op-cgscc>),require<no-op-module>),require<no-op-module>' %s 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-INVALIDATE-ALL-CG
; CHECK-INVALIDATE-ALL-CG: Starting Module pass manager run
; CHECK-INVALIDATE-ALL-CG: Running pass: RequireAnalysisPass
; CHECK-INVALIDATE-ALL-CG: Running analysis: NoOpModuleAnalysis
; CHECK-INVALIDATE-ALL-CG: Starting Module pass manager run
; CHECK-INVALIDATE-ALL-CG: Running pass: RequireAnalysisPass
; CHECK-INVALIDATE-ALL-CG-NOT: Running analysis: NoOpModuleAnalysis
; CHECK-INVALIDATE-ALL-CG: Starting CGSCC pass manager run
; CHECK-INVALIDATE-ALL-CG: Running pass: RequireAnalysisPass
; CHECK-INVALIDATE-ALL-CG: Running analysis: NoOpCGSCCAnalysis
; CHECK-INVALIDATE-ALL-CG: Starting Function pass manager run
; CHECK-INVALIDATE-ALL-CG: Running pass: RequireAnalysisPass
; CHECK-INVALIDATE-ALL-CG: Running analysis: NoOpFunctionAnalysis
; CHECK-INVALIDATE-ALL-CG: Running pass: InvalidateAllAnalysesPass
; CHECK-INVALIDATE-ALL-CG: Invalidating analysis: NoOpFunctionAnalysis
; CHECK-INVALIDATE-ALL-CG: Running pass: RequireAnalysisPass
; CHECK-INVALIDATE-ALL-CG: Running analysis: NoOpFunctionAnalysis
; CHECK-INVALIDATE-ALL-CG: Finished Function pass manager run
; CHECK-INVALIDATE-ALL-CG-NOT: Running analysis: NoOpFunctionAnalysis
; CHECK-INVALIDATE-ALL-CG: Invalidating analysis: NoOpCGSCCAnalysis
; CHECK-INVALIDATE-ALL-CG: Running pass: RequireAnalysisPass
; CHECK-INVALIDATE-ALL-CG: Running analysis: NoOpCGSCCAnalysis
; CHECK-INVALIDATE-ALL-CG: Finished CGSCC pass manager run
; CHECK-INVALIDATE-ALL-CG-NOT: Invalidating analysis: NoOpCGSCCAnalysis
; CHECK-INVALIDATE-ALL-CG: Invalidating analysis: NoOpModuleAnalysis
; CHECK-INVALIDATE-ALL-CG: Running pass: RequireAnalysisPass
; CHECK-INVALIDATE-ALL-CG: Running analysis: NoOpModuleAnalysis
; CHECK-INVALIDATE-ALL-CG: Finished Module pass manager run
; CHECK-INVALIDATE-ALL-CG-NOT: Invalidating analysis: NoOpModuleAnalysis
; CHECK-INVALIDATE-ALL-CG: Running pass: RequireAnalysisPass
; CHECK-INVALIDATE-ALL-CG-NOT: Running analysis: NoOpModuleAnalysis
; CHECK-INVALIDATE-ALL-CG: Finished Module pass manager run

; RUN: opt -disable-output -disable-verify -debug-pass-manager %s 2>&1 \
; RUN:     -passes='require<targetlibinfo>,invalidate<all>,require<targetlibinfo>' \
; RUN:     | FileCheck %s --check-prefix=CHECK-TLI
; CHECK-TLI: Starting Module pass manager run
; CHECK-TLI: Running pass: RequireAnalysisPass
; CHECK-TLI: Running analysis: TargetLibraryAnalysis
; CHECK-TLI: Running pass: InvalidateAllAnalysesPass
; CHECK-TLI-NOT: Invalidating analysis: TargetLibraryAnalysis
; CHECK-TLI: Running pass: RequireAnalysisPass
; CHECK-TLI-NOT: Running analysis: TargetLibraryAnalysis
; CHECK-TLI: Finished Module pass manager run

; RUN: opt -disable-output -disable-verify -debug-pass-manager %s 2>&1 \
; RUN:     -passes='require<targetir>,invalidate<all>,require<targetir>' \
; RUN:     | FileCheck %s --check-prefix=CHECK-TIRA
; CHECK-TIRA: Starting Module pass manager run
; CHECK-TIRA: Running pass: RequireAnalysisPass
; CHECK-TIRA: Running analysis: TargetIRAnalysis
; CHECK-TIRA: Running pass: InvalidateAllAnalysesPass
; CHECK-TIRA-NOT: Invalidating analysis: TargetIRAnalysis
; CHECK-TIRA: Running pass: RequireAnalysisPass
; CHECK-TIRA-NOT: Running analysis: TargetIRAnalysis
; CHECK-TIRA: Finished Module pass manager run

; RUN: opt -disable-output -disable-verify -debug-pass-manager %s 2>&1 \
; RUN:     -passes='require<domtree>' \
; RUN:     | FileCheck %s --check-prefix=CHECK-DT
; CHECK-DT: Starting Module pass manager run
; CHECK-DT: Running pass: RequireAnalysisPass
; CHECK-DT: Running analysis: DominatorTreeAnalysis
; CHECK-DT: Finished Module pass manager run

; RUN: opt -disable-output -disable-verify -debug-pass-manager %s 2>&1 \
; RUN:     -passes='require<basic-aa>' \
; RUN:     | FileCheck %s --check-prefix=CHECK-BASIC-AA
; CHECK-BASIC-AA: Starting Module pass manager run
; CHECK-BASIC-AA: Running pass: RequireAnalysisPass
; CHECK-BASIC-AA: Running analysis: BasicAA
; CHECK-BASIC-AA: Finished Module pass manager run

; RUN: opt -disable-output -disable-verify -debug-pass-manager %s 2>&1 \
; RUN:     -passes='require<aa>' -aa-pipeline='basic-aa' \
; RUN:     | FileCheck %s --check-prefix=CHECK-AA
; CHECK-AA: Starting Module pass manager run
; CHECK-AA: Running pass: RequireAnalysisPass
; CHECK-AA: Running analysis: AAManager
; CHECK-AA: Running analysis: BasicAA
; CHECK-AA: Finished Module pass manager run

; RUN: opt -disable-output -disable-verify -debug-pass-manager %s 2>&1 \
; RUN:     -passes='require<aa>' -aa-pipeline='default' \
; RUN:     | FileCheck %s --check-prefix=CHECK-AA-DEFAULT
; CHECK-AA-DEFAULT: Starting Module pass manager run
; CHECK-AA-DEFAULT: Running pass: RequireAnalysisPass
; CHECK-AA-DEFAULT: Running analysis: AAManager
; CHECK-AA-DEFAULT: Running analysis: BasicAA
; CHECK-AA-DEFAULT: Running analysis: ScopedNoAliasAA
; CHECK-AA-DEFAULT: Running analysis: TypeBasedAA
; CHECK-AA-DEFAULT: Finished Module pass manager run

; RUN: opt -disable-output -disable-verify -debug-pass-manager %s 2>&1 \
; RUN:     -passes='require<aa>,invalidate<domtree>,aa-eval' -aa-pipeline='basic-aa' \
; RUN:     | FileCheck %s --check-prefix=CHECK-AA-FUNCTION-INVALIDATE
; CHECK-AA-FUNCTION-INVALIDATE: Starting Function pass manager run
; CHECK-AA-FUNCTION-INVALIDATE: Running pass: RequireAnalysisPass
; CHECK-AA-FUNCTION-INVALIDATE: Running analysis: AAManager
; CHECK-AA-FUNCTION-INVALIDATE: Running analysis: BasicAA
; CHECK-AA-FUNCTION-INVALIDATE: Running pass: InvalidateAnalysisPass
; CHECK-AA-FUNCTION-INVALIDATE: Invalidating analysis: DominatorTreeAnalysis
; CHECK-AA-FUNCTION-INVALIDATE: Invalidating analysis: BasicAA
; CHECK-AA-FUNCTION-INVALIDATE: Invalidating analysis: AAManager
; CHECK-AA-FUNCTION-INVALIDATE: Running pass: AAEvaluator
; CHECK-AA-FUNCTION-INVALIDATE: Running analysis: AAManager
; CHECK-AA-FUNCTION-INVALIDATE: Running analysis: BasicAA
; CHECK-AA-FUNCTION-INVALIDATE: Finished Function pass manager run

; RUN: opt -disable-output -disable-verify -debug-pass-manager %s 2>&1 \
; RUN:     -passes='require<globals-aa>,function(require<aa>),invalidate<globals-aa>,require<globals-aa>,function(aa-eval)' -aa-pipeline='globals-aa' \
; RUN:     | FileCheck %s --check-prefix=CHECK-AA-MODULE-INVALIDATE
; CHECK-AA-MODULE-INVALIDATE: Starting Module pass manager run
; CHECK-AA-MODULE-INVALIDATE: Running pass: RequireAnalysisPass
; CHECK-AA-MODULE-INVALIDATE: Running analysis: GlobalsAA
; CHECK-AA-MODULE-INVALIDATE: Starting Function pass manager run
; CHECK-AA-MODULE-INVALIDATE: Running pass: RequireAnalysisPass
; CHECK-AA-MODULE-INVALIDATE: Running analysis: AAManager
; CHECK-AA-MODULE-INVALIDATE: Finished Function pass manager run
; CHECK-AA-MODULE-INVALIDATE: Running pass: InvalidateAnalysisPass
; CHECK-AA-MODULE-INVALIDATE: Invalidating analysis: GlobalsAA
; CHECK-AA-MODULE-INVALIDATE: Running pass: RequireAnalysisPass
; CHECK-AA-MODULE-INVALIDATE: Running analysis: GlobalsAA
; CHECK-AA-MODULE-INVALIDATE: Starting Function pass manager run
; CHECK-AA-MODULE-INVALIDATE: Running pass: AAEvaluator
; CHECK-AA-MODULE-INVALIDATE: Finished Function pass manager run
; CHECK-AA-MODULE-INVALIDATE: Finished Module pass manager run

; RUN: opt -disable-output -disable-verify -debug-pass-manager %s 2>&1 \
; RUN:     -passes='require<memdep>' \
; RUN:     | FileCheck %s --check-prefix=CHECK-MEMDEP
; CHECK-MEMDEP: Starting Module pass manager run
; CHECK-MEMDEP: Running pass: RequireAnalysisPass
; CHECK-MEMDEP: Running analysis: MemoryDependenceAnalysis
; CHECK-MEMDEP: Finished Module pass manager run

; RUN: opt -disable-output -disable-verify -debug-pass-manager %s 2>&1 \
; RUN:     -passes='require<callgraph>' \
; RUN:     | FileCheck %s --check-prefix=CHECK-CALLGRAPH
; CHECK-CALLGRAPH: Starting Module pass manager run
; CHECK-CALLGRAPH: Running pass: RequireAnalysisPass
; CHECK-CALLGRAPH: Running analysis: CallGraphAnalysis
; CHECK-CALLGRAPH: Finished Module pass manager run

; RUN: opt -disable-output -disable-verify -debug-pass-manager \
; RUN:     -passes='default<O0>' %s 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-O0
; CHECK-O0: Starting Module pass manager run
; CHECK-O0-NEXT: Finished Module pass manager run

; RUN: opt -disable-output -disable-verify -debug-pass-manager \
; RUN:     -passes='repeat<3>(no-op-module)' %s 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-REPEAT-MODULE-PASS
; CHECK-REPEAT-MODULE-PASS: Starting Module pass manager run
; CHECK-REPEAT-MODULE-PASS-NEXT: Running pass: RepeatedPass
; CHECK-REPEAT-MODULE-PASS-NEXT: Starting Module pass manager run
; CHECK-REPEAT-MODULE-PASS-NEXT: Running pass: NoOpModulePass
; CHECK-REPEAT-MODULE-PASS-NEXT: Finished Module pass manager run
; CHECK-REPEAT-MODULE-PASS-NEXT: Starting Module pass manager run
; CHECK-REPEAT-MODULE-PASS-NEXT: Running pass: NoOpModulePass
; CHECK-REPEAT-MODULE-PASS-NEXT: Finished Module pass manager run
; CHECK-REPEAT-MODULE-PASS-NEXT: Starting Module pass manager run
; CHECK-REPEAT-MODULE-PASS-NEXT: Running pass: NoOpModulePass
; CHECK-REPEAT-MODULE-PASS-NEXT: Finished Module pass manager run
; CHECK-REPEAT-MODULE-PASS-NEXT: Finished Module pass manager run

; RUN: opt -disable-output -disable-verify -debug-pass-manager \
; RUN:     -passes='cgscc(repeat<3>(no-op-cgscc))' %s 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-REPEAT-CGSCC-PASS
; CHECK-REPEAT-CGSCC-PASS: Starting Module pass manager run
; CHECK-REPEAT-CGSCC-PASS-NEXT: Running pass: ModuleToPostOrderCGSCCPassAdaptor
; CHECK-REPEAT-CGSCC-PASS-NEXT: Running analysis: InnerAnalysisManagerProxy<{{.*(CGSCCAnalysisManager|AnalysisManager<.*LazyCallGraph::SCC.*>).*}},{{.*}}Module>
; CHECK-REPEAT-CGSCC-PASS-NEXT: Running analysis: InnerAnalysisManagerProxy<{{.*(FunctionAnalysisManager|AnalysisManager<.*Function.*>).*}},{{.*}}Module>
; CHECK-REPEAT-CGSCC-PASS-NEXT: Running analysis: LazyCallGraphAnalysis
; CHECK-REPEAT-CGSCC-PASS-NEXT: Running analysis: TargetLibraryAnalysis
; CHECK-REPEAT-CGSCC-PASS-NEXT: Running analysis: PassInstrumentationAnalysis
; CHECK-REPEAT-CGSCC-PASS-NEXT: Running analysis: FunctionAnalysisManagerCGSCCProxy
; CHECK-REPEAT-CGSCC-PASS-NEXT: Running analysis: PassInstrumentationAnalysis
; CHECK-REPEAT-CGSCC-PASS-NEXT: Running analysis: OuterAnalysisManagerProxy<{{.*}}LazyCallGraph::SCC{{.*}}>
; CHECK-REPEAT-CGSCC-PASS-NEXT: Starting CGSCC pass manager run
; CHECK-REPEAT-CGSCC-PASS-NEXT: Running pass: RepeatedPass
; CHECK-REPEAT-CGSCC-PASS-NEXT: Starting CGSCC pass manager run
; CHECK-REPEAT-CGSCC-PASS-NEXT: Running pass: NoOpCGSCCPass
; CHECK-REPEAT-CGSCC-PASS-NEXT: Finished CGSCC pass manager run
; CHECK-REPEAT-CGSCC-PASS-NEXT: Starting CGSCC pass manager run
; CHECK-REPEAT-CGSCC-PASS-NEXT: Running pass: NoOpCGSCCPass
; CHECK-REPEAT-CGSCC-PASS-NEXT: Finished CGSCC pass manager run
; CHECK-REPEAT-CGSCC-PASS-NEXT: Starting CGSCC pass manager run
; CHECK-REPEAT-CGSCC-PASS-NEXT: Running pass: NoOpCGSCCPass
; CHECK-REPEAT-CGSCC-PASS-NEXT: Finished CGSCC pass manager run
; CHECK-REPEAT-CGSCC-PASS-NEXT: Finished CGSCC pass manager run
; CHECK-REPEAT-CGSCC-PASS-NEXT: Finished Module pass manager run

; RUN: opt -disable-output -disable-verify -debug-pass-manager \
; RUN:     -passes='function(repeat<3>(no-op-function))' %s 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-REPEAT-FUNCTION-PASS
; CHECK-REPEAT-FUNCTION-PASS: Starting Module pass manager run
; CHECK-REPEAT-FUNCTION-PASS-NEXT: Running pass: ModuleToFunctionPassAdaptor
; CHECK-REPEAT-FUNCTION-PASS-NEXT: Running analysis: InnerAnalysisManagerProxy<{{.*}}>
; CHECK-REPEAT-FUNCTION-PASS-NEXT: Running analysis: PassInstrumentationAnalysis
; CHECK-REPEAT-FUNCTION-PASS-NEXT: Starting Function pass manager run
; CHECK-REPEAT-FUNCTION-PASS-NEXT: Running pass: RepeatedPass
; CHECK-REPEAT-FUNCTION-PASS-NEXT: Starting Function pass manager run
; CHECK-REPEAT-FUNCTION-PASS-NEXT: Running pass: NoOpFunctionPass
; CHECK-REPEAT-FUNCTION-PASS-NEXT: Finished Function pass manager run
; CHECK-REPEAT-FUNCTION-PASS-NEXT: Starting Function pass manager run
; CHECK-REPEAT-FUNCTION-PASS-NEXT: Running pass: NoOpFunctionPass
; CHECK-REPEAT-FUNCTION-PASS-NEXT: Finished Function pass manager run
; CHECK-REPEAT-FUNCTION-PASS-NEXT: Starting Function pass manager run
; CHECK-REPEAT-FUNCTION-PASS-NEXT: Running pass: NoOpFunctionPass
; CHECK-REPEAT-FUNCTION-PASS-NEXT: Finished Function pass manager run
; CHECK-REPEAT-FUNCTION-PASS-NEXT: Finished Function pass manager run
; CHECK-REPEAT-FUNCTION-PASS-NEXT: Finished Module pass manager run

; RUN: opt -disable-output -disable-verify -debug-pass-manager \
; RUN:     -passes='loop(repeat<3>(no-op-loop))' %s 2>&1 \
; RUN:     | FileCheck %s --check-prefix=CHECK-REPEAT-LOOP-PASS
; CHECK-REPEAT-LOOP-PASS: Starting Module pass manager run
; CHECK-REPEAT-LOOP-PASS-NEXT: Running pass: ModuleToFunctionPassAdaptor
; CHECK-REPEAT-LOOP-PASS-NEXT: Running analysis: InnerAnalysisManagerProxy<{{.*}}>
; CHECK-REPEAT-LOOP-PASS-NEXT: Running analysis: PassInstrumentationAnalysis
; CHECK-REPEAT-LOOP-PASS-NEXT: Starting Function pass manager run
; CHECK-REPEAT-LOOP-PASS-NEXT: Running pass: FunctionToLoopPassAdaptor
; CHECK-REPEAT-LOOP-PASS-NEXT: Starting Function pass manager run
; CHECK-REPEAT-LOOP-PASS-NEXT: Running pass: LoopSimplify
; CHECK-REPEAT-LOOP-PASS-NEXT: Running analysis: LoopAnalysis
; CHECK-REPEAT-LOOP-PASS-NEXT: Running analysis: DominatorTreeAnalysis
; CHECK-REPEAT-LOOP-PASS-NEXT: Running analysis: AssumptionAnalysis
; CHECK-REPEAT-LOOP-PASS-NEXT: Invalidating all non-preserved analyses
; CHECK-REPEAT-LOOP-PASS-NEXT: Running pass: LCSSAPass
; CHECK-REPEAT-LOOP-PASS-NEXT: Finished Function pass manager run
; CHECK-REPEAT-LOOP-PASS-NEXT: Running analysis: AAManager
; CHECK-REPEAT-LOOP-PASS-NEXT: Running analysis: TargetLibraryAnalysis
; CHECK-REPEAT-LOOP-PASS-NEXT: Running analysis: ScalarEvolutionAnalysis
; CHECK-REPEAT-LOOP-PASS-NEXT: Running analysis: TargetIRAnalysis
; CHECK-REPEAT-LOOP-PASS-NEXT: Running analysis: InnerAnalysisManagerProxy<{{.*}}>
; CHECK-REPEAT-LOOP-PASS-NEXT: Starting Loop pass manager run
; CHECK-REPEAT-LOOP-PASS-NEXT: Running analysis: PassInstrumentationAnalysis
; CHECK-REPEAT-LOOP-PASS-NEXT: Running pass: RepeatedPass
; CHECK-REPEAT-LOOP-PASS-NEXT: Starting Loop pass manager run
; CHECK-REPEAT-LOOP-PASS-NEXT: Running pass: NoOpLoopPass
; CHECK-REPEAT-LOOP-PASS-NEXT: Finished Loop pass manager run
; CHECK-REPEAT-LOOP-PASS-NEXT: Starting Loop pass manager run
; CHECK-REPEAT-LOOP-PASS-NEXT: Running pass: NoOpLoopPass
; CHECK-REPEAT-LOOP-PASS-NEXT: Finished Loop pass manager run
; CHECK-REPEAT-LOOP-PASS-NEXT: Starting Loop pass manager run
; CHECK-REPEAT-LOOP-PASS-NEXT: Running pass: NoOpLoopPass
; CHECK-REPEAT-LOOP-PASS-NEXT: Finished Loop pass manager run
; CHECK-REPEAT-LOOP-PASS-NEXT: Finished Loop pass manager run
; CHECK-REPEAT-LOOP-PASS-NEXT: Finished Function pass manager run
; CHECK-REPEAT-LOOP-PASS-NEXT: Invalidating all non-preserved analyses
; CHECK-REPEAT-LOOP-PASS-NEXT: Finished Module pass manager run

define void @foo(i1 %x, i8* %p1, i8* %p2) {
entry:
  store i8 42, i8* %p1
  br i1 %x, label %loop, label %exit

loop:
  %tmp1 = load i8, i8* %p2
  br label %loop

exit:
  ret void
}

declare void @bar()

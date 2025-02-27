// RUN: mlir-opt %s -inline -split-input-file | FileCheck %s

func.func @inner_func_inlinable(%ptr : !llvm.ptr) -> i32 {
  %0 = llvm.mlir.constant(42 : i32) : i32
  llvm.store %0, %ptr { alignment = 8 } : i32, !llvm.ptr
  %1 = llvm.load %ptr { alignment = 8 } : !llvm.ptr -> i32
  return %1 : i32
}

// CHECK-LABEL: func.func @test_inline(
// CHECK-SAME: %[[PTR:[a-zA-Z0-9_]+]]
// CHECK-NEXT: %[[CST:.*]] = llvm.mlir.constant(42 : i32) : i32
// CHECK-NEXT: llvm.store %[[CST]], %[[PTR]]
// CHECK-NEXT: %[[RES:.+]] = llvm.load %[[PTR]]
// CHECK-NEXT: return %[[RES]] : i32
func.func @test_inline(%ptr : !llvm.ptr) -> i32 {
  %0 = call @inner_func_inlinable(%ptr) : (!llvm.ptr) -> i32
  return %0 : i32
}

// -----

func.func @inner_func_not_inlinable() -> i32 {
  %0 = llvm.inline_asm has_side_effects "foo", "bar" : () -> i32
  return %0 : i32
}

// CHECK-LABEL: func.func @test_not_inline() -> i32 {
// CHECK-NEXT: %[[RES:.*]] = call @inner_func_not_inlinable() : () -> i32
// CHECK-NEXT: return %[[RES]] : i32
func.func @test_not_inline() -> i32 {
  %0 = call @inner_func_not_inlinable() : () -> i32
  return %0 : i32
}

// -----

llvm.metadata @metadata {
  llvm.access_group @group
  llvm.return
}

func.func private @with_mem_attr(%ptr : !llvm.ptr) {
  %0 = llvm.mlir.constant(42 : i32) : i32
  // Do not inline load/store operations that carry attributes requiring
  // handling while inlining, until this is supported by the inliner.
  llvm.store %0, %ptr { access_groups = [@metadata::@group] }: i32, !llvm.ptr
  return
}

// CHECK-LABEL: func.func @test_not_inline
// CHECK-NEXT: call @with_mem_attr
// CHECK-NEXT: return
func.func @test_not_inline(%ptr : !llvm.ptr) {
  call @with_mem_attr(%ptr) : (!llvm.ptr) -> ()
  return
}

// -----
// Check that llvm.return is correctly handled

func.func @func(%arg0 : i32) -> i32  {
  llvm.return %arg0 : i32
}
// CHECK-LABEL: @llvm_ret
// CHECK-NOT: call
// CHECK:  return %arg0
func.func @llvm_ret(%arg0 : i32) -> i32 {
  %res = call @func(%arg0) : (i32) -> (i32)
  return %res : i32
}

// -----

// Include all function attributes that don't prevent inlining
llvm.func internal fastcc @callee() -> (i32) attributes { function_entry_count = 42 : i64, dso_local } {
  %0 = llvm.mlir.constant(42 : i32) : i32
  llvm.return %0 : i32
}

// CHECK-LABEL: llvm.func @caller
// CHECK-NEXT: %[[CST:.+]] = llvm.mlir.constant
// CHECK-NEXT: llvm.return %[[CST]]
llvm.func @caller() -> (i32) {
  // Include all call attributes that don't prevent inlining.
  %0 = llvm.call @callee() { fastmathFlags = #llvm.fastmath<nnan, ninf>, branch_weights = dense<42> : vector<1xi32> } : () -> (i32)
  llvm.return %0 : i32
}

// -----

llvm.func @foo() -> (i32) attributes { passthrough = ["noinline"] } {
  %0 = llvm.mlir.constant(0 : i32) : i32
  llvm.return %0 : i32
}

llvm.func @bar() -> (i32) attributes { passthrough = ["noinline"] } {
  %0 = llvm.mlir.constant(1 : i32) : i32
  llvm.return %0 : i32
}

llvm.func @callee_with_multiple_blocks(%cond: i1) -> (i32) {
  llvm.cond_br %cond, ^bb1, ^bb2
^bb1:
  %0 = llvm.call @foo() : () -> (i32)
  llvm.br ^bb3(%0: i32)
^bb2:
  %1 = llvm.call @bar() : () -> (i32)
  llvm.br ^bb3(%1: i32)
^bb3(%arg: i32):
  llvm.return %arg : i32
}

// CHECK-LABEL: llvm.func @caller
// CHECK-NEXT: llvm.cond_br {{.+}}, ^[[BB1:.+]], ^[[BB2:.+]]
// CHECK-NEXT: ^[[BB1]]:
// CHECK-NEXT: llvm.call @foo
// CHECK-NEXT: llvm.br ^[[BB3:[a-zA-Z0-9_]+]]
// CHECK-NEXT: ^[[BB2]]:
// CHECK-NEXT: llvm.call @bar
// CHECK-NEXT: llvm.br ^[[BB3]]
// CHECK-NEXT: ^[[BB3]]
// CHECK-NEXT: llvm.br ^[[BB4:[a-zA-Z0-9_]+]]
// CHECK-NEXT: ^[[BB4]]
// CHECK-NEXT: llvm.return
llvm.func @caller(%cond: i1) -> (i32) {
  %0 = llvm.call @callee_with_multiple_blocks(%cond) : (i1) -> (i32)
  llvm.return %0 : i32
}

// -----

llvm.func @personality() -> i32

llvm.func @callee() -> (i32) attributes { personality = @personality } {
  %0 = llvm.mlir.constant(42 : i32) : i32
  llvm.return %0 : i32
}

// CHECK-LABEL: llvm.func @caller
// CHECK-NEXT: llvm.call @callee
// CHECK-NEXT: return
llvm.func @caller() -> (i32) {
  %0 = llvm.call @callee() : () -> (i32)
  llvm.return %0 : i32
}

// -----

llvm.func @callee() attributes { passthrough = ["foo", "bar"] } {
  llvm.return
}

// CHECK-LABEL: llvm.func @caller
// CHECK-NEXT: llvm.return
llvm.func @caller() {
  llvm.call @callee() : () -> ()
  llvm.return
}

// -----

llvm.func @callee_noinline() attributes { passthrough = ["noinline"] } {
  llvm.return
}

llvm.func @callee_optnone() attributes { passthrough = ["optnone"] } {
  llvm.return
}

llvm.func @callee_noduplicate() attributes { passthrough = ["noduplicate"] } {
  llvm.return
}

llvm.func @callee_presplitcoroutine() attributes { passthrough = ["presplitcoroutine"] } {
  llvm.return
}

llvm.func @callee_returns_twice() attributes { passthrough = ["returns_twice"] } {
  llvm.return
}

llvm.func @callee_strictfp() attributes { passthrough = ["strictfp"] } {
  llvm.return
}

// CHECK-LABEL: llvm.func @caller
// CHECK-NEXT: llvm.call @callee_noinline
// CHECK-NEXT: llvm.call @callee_optnone
// CHECK-NEXT: llvm.call @callee_noduplicate
// CHECK-NEXT: llvm.call @callee_presplitcoroutine
// CHECK-NEXT: llvm.call @callee_returns_twice
// CHECK-NEXT: llvm.call @callee_strictfp
// CHECK-NEXT: llvm.return
llvm.func @caller() {
  llvm.call @callee_noinline() : () -> ()
  llvm.call @callee_optnone() : () -> ()
  llvm.call @callee_noduplicate() : () -> ()
  llvm.call @callee_presplitcoroutine() : () -> ()
  llvm.call @callee_returns_twice() : () -> ()
  llvm.call @callee_strictfp() : () -> ()
  llvm.return
}

// -----

llvm.func @static_alloca() -> f32 {
  %0 = llvm.mlir.constant(4 : i32) : i32
  %1 = llvm.alloca %0 x f32 : (i32) -> !llvm.ptr
  %2 = llvm.load %1 : !llvm.ptr -> f32
  llvm.return %2 : f32
}

llvm.func @dynamic_alloca(%size : i32) -> f32 {
  %0 = llvm.add %size, %size : i32
  %1 = llvm.alloca %0 x f32 : (i32) -> !llvm.ptr
  %2 = llvm.load %1 : !llvm.ptr -> f32
  llvm.return %2 : f32
}

// CHECK-LABEL: llvm.func @test_inline
llvm.func @test_inline(%cond : i1, %size : i32) -> f32 {
  // Check that the static alloca was moved to the entry block after inlining
  // with its size defined by a constant.
  // CHECK-NOT: ^{{.+}}:
  // CHECK-NEXT: llvm.mlir.constant
  // CHECK-NEXT: llvm.alloca
  // CHECK: llvm.cond_br
  llvm.cond_br %cond, ^bb1, ^bb2
  // CHECK: ^{{.+}}:
^bb1:
  // CHECK-NOT: llvm.call @static_alloca
  // CHECK: llvm.intr.lifetime.start
  %0 = llvm.call @static_alloca() : () -> f32
  // CHECK: llvm.intr.lifetime.end
  // CHECK: llvm.br
  llvm.br ^bb3(%0: f32)
  // CHECK: ^{{.+}}:
^bb2:
  // Check that the dynamic alloca was inlined, but that it was not moved to the
  // entry block.
  // CHECK: llvm.add
  // CHECK-NEXT: llvm.alloca
  // CHECK-NOT: llvm.call @dynamic_alloca
  %1 = llvm.call @dynamic_alloca(%size) : (i32) -> f32
  // CHECK: llvm.br
  llvm.br ^bb3(%1: f32)
  // CHECK: ^{{.+}}:
^bb3(%arg : f32):
  llvm.return %arg : f32
}

// -----

llvm.func @static_alloca_not_in_entry(%cond : i1) -> f32 {
  llvm.cond_br %cond, ^bb1, ^bb2
^bb1:
  %0 = llvm.mlir.constant(4 : i32) : i32
  %1 = llvm.alloca %0 x f32 : (i32) -> !llvm.ptr
  llvm.br ^bb3(%1: !llvm.ptr)
^bb2:
  %2 = llvm.mlir.constant(8 : i32) : i32
  %3 = llvm.alloca %2 x f32 : (i32) -> !llvm.ptr
  llvm.br ^bb3(%3: !llvm.ptr)
^bb3(%ptr : !llvm.ptr):
  %4 = llvm.load %ptr : !llvm.ptr -> f32
  llvm.return %4 : f32
}

// CHECK-LABEL: llvm.func @test_inline
llvm.func @test_inline(%cond : i1) -> f32 {
  // Make sure the alloca was not moved to the entry block.
  // CHECK-NOT: llvm.alloca
  // CHECK: llvm.cond_br
  // CHECK: llvm.alloca
  %0 = llvm.call @static_alloca_not_in_entry(%cond) : (i1) -> f32
  llvm.return %0 : f32
}

// -----

llvm.func @static_alloca(%cond: i1) -> f32 {
  %0 = llvm.mlir.constant(4 : i32) : i32
  %1 = llvm.alloca %0 x f32 : (i32) -> !llvm.ptr
  llvm.cond_br %cond, ^bb1, ^bb2
^bb1:
  %2 = llvm.load %1 : !llvm.ptr -> f32
  llvm.return %2 : f32
^bb2:
  %3 = llvm.mlir.constant(3.14192 : f32) : f32
  llvm.return %3 : f32
}

// CHECK-LABEL: llvm.func @test_inline
llvm.func @test_inline(%cond0 : i1, %cond1 : i1, %funcArg : f32) -> f32 {
  // CHECK-NOT: llvm.cond_br
  // CHECK: %[[PTR:.+]] = llvm.alloca
  // CHECK: llvm.cond_br %{{.+}}, ^[[BB1:.+]], ^{{.+}}
  llvm.cond_br %cond0, ^bb1, ^bb2
  // CHECK: ^[[BB1]]
^bb1:
  // Make sure the lifetime begin intrinsic has been inserted where the call
  // used to be, even though the alloca has been moved to the entry block.
  // CHECK-NEXT: llvm.intr.lifetime.start 4, %[[PTR]]
  %0 = llvm.call @static_alloca(%cond1) : (i1) -> f32
  // CHECK: llvm.cond_br %{{.+}}, ^[[BB2:.+]], ^[[BB3:.+]]
  llvm.br ^bb3(%0: f32)
  // Make sure the lifetime end intrinsic has been inserted at both former
  // return sites of the callee.
  // CHECK: ^[[BB2]]:
  // CHECK-NEXT: llvm.load
  // CHECK-NEXT: llvm.intr.lifetime.end 4, %[[PTR]]
  // CHECK: ^[[BB3]]:
  // CHECK-NEXT: llvm.intr.lifetime.end 4, %[[PTR]]
^bb2:
  llvm.br ^bb3(%funcArg: f32)
^bb3(%blockArg: f32):
  llvm.return %blockArg : f32
}

// -----

llvm.func @alloca_with_lifetime(%cond: i1) -> f32 {
  %0 = llvm.mlir.constant(4 : i32) : i32
  %1 = llvm.alloca %0 x f32 : (i32) -> !llvm.ptr
  llvm.intr.lifetime.start 4, %1 : !llvm.ptr
  %2 = llvm.load %1 : !llvm.ptr -> f32
  llvm.intr.lifetime.end 4, %1 : !llvm.ptr
  %3 = llvm.fadd %2, %2 : f32
  llvm.return %3 : f32
}

// CHECK-LABEL: llvm.func @test_inline
llvm.func @test_inline(%cond0 : i1, %cond1 : i1, %funcArg : f32) -> f32 {
  // CHECK-NOT: llvm.cond_br
  // CHECK: %[[PTR:.+]] = llvm.alloca
  // CHECK: llvm.cond_br %{{.+}}, ^[[BB1:.+]], ^{{.+}}
  llvm.cond_br %cond0, ^bb1, ^bb2
  // CHECK: ^[[BB1]]
^bb1:
  // Make sure the original lifetime intrinsic has been preserved, rather than
  // inserting a new one with a larger scope.
  // CHECK: llvm.intr.lifetime.start 4, %[[PTR]]
  // CHECK-NEXT: llvm.load %[[PTR]]
  // CHECK-NEXT: llvm.intr.lifetime.end 4, %[[PTR]]
  // CHECK: llvm.fadd
  // CHECK-NOT: llvm.intr.lifetime.end
  %0 = llvm.call @alloca_with_lifetime(%cond1) : (i1) -> f32
  llvm.br ^bb3(%0: f32)
^bb2:
  llvm.br ^bb3(%funcArg: f32)
^bb3(%blockArg: f32):
  llvm.return %blockArg : f32
}

// -----

llvm.func @with_byval_arg(%ptr : !llvm.ptr { llvm.byval = f64 }) {
  llvm.return
}

// CHECK-LABEL: llvm.func @test_byval
// CHECK-SAME: %[[PTR:[a-zA-Z0-9_]+]]: !llvm.ptr
// CHECK: %[[ALLOCA:.+]] = llvm.alloca %{{.+}} x f64
// CHECK: "llvm.intr.memcpy"(%[[ALLOCA]], %[[PTR]]
llvm.func @test_byval(%ptr : !llvm.ptr) {
  llvm.call @with_byval_arg(%ptr) : (!llvm.ptr) -> ()
  llvm.return
}

// -----

llvm.func @with_byval_arg(%ptr : !llvm.ptr { llvm.byval = f64 }) attributes {memory = #llvm.memory_effects<other = readwrite, argMem = read, inaccessibleMem = readwrite>} {
  llvm.return
}

// CHECK-LABEL: llvm.func @test_byval_read_only
// CHECK-NOT: llvm.call
// CHECK-NEXT: llvm.return
llvm.func @test_byval_read_only(%ptr : !llvm.ptr) {
  llvm.call @with_byval_arg(%ptr) : (!llvm.ptr) -> ()
  llvm.return
}

// -----

llvm.func @with_byval_arg(%ptr : !llvm.ptr { llvm.byval = f64 }) attributes {memory = #llvm.memory_effects<other = readwrite, argMem = write, inaccessibleMem = readwrite>} {
  llvm.return
}

// CHECK-LABEL: llvm.func @test_byval_write_only
// CHECK-SAME: %[[PTR:[a-zA-Z0-9_]+]]: !llvm.ptr
// CHECK: %[[ALLOCA:.+]] = llvm.alloca %{{.+}} x f64
// CHECK: "llvm.intr.memcpy"(%[[ALLOCA]], %[[PTR]]
llvm.func @test_byval_write_only(%ptr : !llvm.ptr) {
  llvm.call @with_byval_arg(%ptr) : (!llvm.ptr) -> ()
  llvm.return
}

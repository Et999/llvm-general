#ifndef __LLVM_GENERAL_INTERNAL_FFI__MDNODE__H__
#define __LLVM_GENERAL_INTERNAL_FFI__MDNODE__H__

#include "llvm/Support/CBindingWrapping.h"

extern "C" {
  typedef struct LLVMOpaqueMDNodeContext *LLVMMDNodeRef;
}

DEFINE_SIMPLE_CONVERSION_FUNCTIONS(llvm::MDNode,LLVMMDNodeRef)


#endif

#define __STDC_LIMIT_MACROS
#include "llvm/Config/llvm-config.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Metadata.h"
#include "llvm-c/Core.h"

#include "LLVM/General/Internal/FFI/MDNode.h"

using namespace llvm;

extern "C" {

unsigned LLVM_General_GetMDKindNames(
	LLVMContextRef c,
	const char **s,
	unsigned *l,
	unsigned n
) {
	SmallVector<StringRef, 16> ns;
	unwrap(c)->getMDKindNames(ns);
	if (ns.size() <= n) {
		for(unsigned i=0; i < ns.size(); ++i) {
			s[i] = ns[i].data();
			l[i] = ns[i].size();
		}
	}
	return ns.size();
}

unsigned LLVM_General_GetMDNodeNumOperands(LLVMMDNodeRef v) {
	return unwrap(v)->getNumOperands();
}

void LLVM_General_NamedMetadataAddOperands(
	NamedMDNode *n,
	LLVMMDNodeRef *ops,
	unsigned nOps
) {
	for(unsigned i = 0; i != nOps; ++i) n->addOperand(unwrap(ops[i]));
}

const char *LLVM_General_GetNamedMetadataName(
	NamedMDNode *n,
	unsigned *len
) {
	StringRef s = n->getName();
	*len = s.size();
	return s.data();
}

unsigned LLVM_General_GetNamedMetadataNumOperands(NamedMDNode *n) {
	return n->getNumOperands();
}

void LLVM_General_GetNamedMetadataOperands(NamedMDNode *n, LLVMMDNodeRef *dest) {
	for(unsigned i = 0; i != n->getNumOperands(); ++i)
		dest[i] = wrap(n->getOperand(i));
}

LLVMMDNodeRef LLVM_General_CreateTemporaryMDNodeInContext(LLVMContextRef c) {
	return wrap(MDNode::getTemporary(*unwrap(c), ArrayRef<Metadata *>()));
}

void LLVM_General_DestroyTemporaryMDNode(LLVMMDNodeRef v) {
	MDNode::deleteTemporary(unwrap(v));
}

}


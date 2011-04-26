// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010-2011 by Rainer Schuetze, All Rights Reserved
//
// License for redistribution is given by the Artistic License 2.0
// see file LICENSE for further details

module vdc.ast.node;

import vdc.util;
import vdc.semantic;
import vdc.lexer;
import vdc.ast.expr;

import std.exception;
import std.stdio;
import std.string;
import std.conv;
import std.algorithm;

class Node
{
	TokenId id;
	Attribute attr;
	Annotation annotation;
	TextSpan span; // file extracted from parent module
	
	Node parent;
	Node[] members;
	
	// semantic data
	int semanticSearches;
	Scope scop;
	
	this()
	{
		// default constructor need for clone()
	}
	
	this(ref const(TextSpan) _span)
	{
		span = _span;
	}
	this(Token tok)
	{
		id = tok.id;
		span = tok.span;
	}
	this(TokenId _id, ref const(TextSpan) _span)
	{
		id = _id;
		span = _span;
	}

	mixin template ForwardCtor()
	{
		this()
		{
			// default constructor need for clone()
		}
		this(ref const(TextSpan) _span)
		{
			super(_span);
		}
		this(Token tok)
		{
			super(tok);
		}
		this(TokenId _id, ref const(TextSpan) _span)
		{
			super(_id, _span);
		}
	}
		
	mixin template ForwardCtorTok()
	{
		this() {} // default constructor need for clone()
		
		this(Token tok)
		{
			super(tok);
		}
	}
	
	mixin template ForwardCtorNoId()
	{
		this() {} // default constructor need for clone()
		
		this(ref const(TextSpan) _span)
		{
			super(_span);
		}
		this(Token tok)
		{
			super(tok.span);
		}
	}
	
	void reinit()
	{
		id = 0;
		attr = 0;
		annotation = 0;
		members.length = 0;
		clearSpan();
	}

	Node clone()
	{
		Node	n = static_cast!Node(this.classinfo.create());
		
		n.id = id;
		n.attr = attr;
		n.annotation = annotation;
		n.span = span;
		
		foreach(m; members)
			n.addMember(m.clone());
		
		return n;
	}

	bool compare(const(Node) n) const
	{
		if(this.classinfo !is n.classinfo)
			return false;
		
		if(n.id != id || n.attr != attr || n.annotation != annotation)
			return false;
		// ignore span
		
		if(members.length != n.members.length)
			return false;
			
		for(int m = 0; m < members.length; m++)
			if(!members[m].compare(n.members[m]))
				return false;
	
		return true;
	}
	
	////////////////////////////////////////////////////////////
	abstract void toD(CodeWriter writer)
	{
		writer(this.classinfo.name);
		writer.nl();
		
		auto indent = CodeIndenter(writer);
		foreach(c; members)
			writer(c);
	}

	void toC(CodeWriter writer)
	{
		toD(writer);
	}

	////////////////////////////////////////////////////////////
	static string genCheckState(string state)
	{
		return "
			if(" ~ state ~ "!= 0)
				return;
			" ~ state ~ " = 1;
			scope(exit) " ~ state ~ " = 2;
		";
	}

	enum SemanticState
	{
		None,
		ExpandingNonScopeMembers,
		ExpandedNonScopeMembers,
		AddingSymbols,
		AddedSymbols,
		ResolvingSymbols,
		ResolvedSymbols,
	}
	int semanticState;
	
	void expandNonScopeMembers(Scope sc)
	{
		if(semanticState >= SemanticState.ExpandingNonScopeMembers)
			return;
		
		semanticState = SemanticState.ExpandingNonScopeMembers;
		Node[1] narray;
		for(int m = 0; m < members.length; )
		{
			Node n = members[m];
			narray[0] = n;
			Node[] nm = n.expandNonScope(sc, narray);
			if(nm.length == 1 && nm[0] == n)
				m++;
			else
				replaceMember(m, nm);
		}
		semanticState = SemanticState.ExpandedNonScopeMembers;
	}
	
	Node[] expandNonScope(Scope sc, Node[] athis)
	{
		return athis;
	}
	
	void addMemberSymbols(Scope sc)
	{
		if(semanticState >= SemanticState.AddingSymbols)
			return;
		
		semanticState = SemanticState.AddingSymbols;
		for(int m = 0; m < members.length; m++)
			members[m].addSymbols(sc);

		semanticState = SemanticState.AddedSymbols;
	}
	
	void addSymbols(Scope sc)
	{
	}
	
	void semantic(Scope sc)
	{
//		throw new SemanticException(text(this, ".semantic not implemented"));
		foreach(m; members)
			m.semantic(sc);
	}

	////////////////////////////////////////////////////////////
	void addMember(Node m) 
	{
		members ~= m;
		m.parent = this;
	}
	
	void replaceMember(Node m, Node[] nm) 
	{
		int n = std.algorithm.countUntil(members, m);
		assert(n >= 0);
		replaceMember(n, nm);
	}
	
	void replaceMember(int m, Node[] nm) 
	{
		if(m < members.length)
			members[m].parent = null;
		members = members[0..m] ~ nm ~ members[m+1..$];
		foreach(n; nm)
			n.parent = this;
	}
	
	T getMember(T = Node)(int idx) 
	{ 
		if (idx < 0 || idx >= members.length)
			return null;
		return static_cast!T(members[idx]);
	}

	////////////////////////////////////////////////////////////
	void extendSpan(ref const(TextSpan) _span)
	{
		span.end.line = _span.end.line;
		span.end.index = _span.end.index;
	}
	void limitSpan(ref const(TextSpan) _span)
	{
		span.end.line = _span.end.line;
		span.end.index = _span.end.index;
	}
	void clearSpan()
	{
		span.end.line = span.start.line;
		span.end.index = span.start.index;
	}
}


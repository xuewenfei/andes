// Class exprp, printing or string output from physvar and expr
// Copyright (C) 2001 by Joel A. Shapiro -- All Rights Reserved
// Modifications by Brett van de Sande, 2005-2008
//
//  This file is part of the Andes Solver.
//
//  The Andes Solver is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Lesser General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  The Andes Solver is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Lesser General Public License for more details.
//
//  You should have received a copy of the GNU Lesser General Public License
//  along with the Andes Solver.  If not, see <http://www.gnu.org/licenses/>.

#include <string>
#include "decl.h"
#include "unitabr.h"
#include <stdio.h>
#include <math.h>
using namespace std;
#include "dbg.h"

#define DBG(A) DBGF(EXPRDB,A)

extern vector<physvar *> * canonvars;
extern unitabrs unittable;
extern vector<double> *numsols;

numvalexp * getfromunits(const string & unitstr);

// print out exponent
string ustrp(double dpow)      
{				
  int q;
  char buf[8];
  if (lookslikeint(dpow,q))
    {
      if (q==1) return (string(""));
      else sprintf(buf,"^%d",q);
    }
  else sprintf(buf,"^%.1lf",dpow); 
  return(string(buf));
}

////////////////////////////////////////////////////////////////////////////
/******************************** PRINTING ********************************/
////////////////////////////////////////////////////////////////////////////

/************************************************************************
 * unitprint   return a string representing the units in a dimens	*
 ************************************************************************/
string unitprint(const dimens dim)
{
  string unitstr = unittable.match(dim);
  if (unitstr.compare("None") == 0) {
    unitstr.erase();
    if(dim.unknp()) 
      unitstr.append("unknown_units");
    else if(dim.inconsp()) 
      unitstr.append("inconsistent_units");
    else {
      // do all numerators
      if (dim.getlengthd() > 0) 
	unitstr.append("m" + ustrp(dim.getlengthd())+".");
      if (dim.getmassd() > 0) 
	unitstr.append("kg" + ustrp(dim.getmassd())+".");
      if (dim.gettimed() > 0) 
	unitstr.append("s" + ustrp(dim.gettimed())+".");
      if (dim.getcharged() > 0) 
	unitstr.append("C" + ustrp(dim.getcharged())+".");
      if (dim.gettempd() > 0) 
	unitstr.append("K" + ustrp(dim.gettempd())+".");

      int usl = unitstr.length();
      if(usl > 0) {
        // add denominator to result
	if (unitstr[usl-1] == '.') unitstr.erase(usl-1,1); //always true
	if (dim.getlengthd() < 0) 
	  unitstr.append("/m" + ustrp(-dim.getlengthd()));
	if (dim.getmassd() < 0) 
	  unitstr.append("/kg" + ustrp(-dim.getmassd()));
	if (dim.gettimed() < 0) 
	  unitstr.append("/s" + ustrp(-dim.gettimed()));
	if (dim.getcharged() < 0) 
	  unitstr.append("/C" + ustrp(-dim.getcharged()));
	if (dim.gettempd() < 0) 
	  unitstr.append("/K" + ustrp(-dim.gettempd()));
      } else {
        // only denominator: use negative powers
	if (dim.getlengthd() < 0) 
	  unitstr.append("m" + ustrp(dim.getlengthd())+".");
	if (dim.getmassd() < 0) 
	  unitstr.append("kg" + ustrp(dim.getmassd())+".");
	if (dim.gettimed() < 0) 
	  unitstr.append("s" + ustrp(dim.gettimed())+".");
	if (dim.getcharged() < 0) 
	  unitstr.append("C" + ustrp(dim.getcharged())+".");
	if (dim.gettempd() < 0) 
	  unitstr.append("K" + ustrp(dim.gettempd())+".");
	usl = unitstr.length();
	if ((usl > 0) && (unitstr[usl-1] == '.')) unitstr.erase(usl-1,1);
     }
    }
  }
  return(unitstr);
}


/************************************************************************
 * expr::getInfix   returns a string representing an expr in fully 	*
 * 	parenthesized infix format					*
 ************************************************************************/

string numvalexp::getInfix() const {

  // WARNING:  This code is repeated three times in this file
  int q;
  char valuenum[30];
  // The number of digits are supposed to match DBL_EPSILON
  DBG( cout << "getInfix on numval" << endl);
  // don't truncate nonzero numbers near zero
  if ((value==0. || fabs(value)>0.5) && lookslikeint(value,q))
    sprintf(valuenum,"%d",q);
  else if ((fabs(value) < 1.) && (fabs(value)> 0.001))
    sprintf(valuenum,"%.17lf",value);
  else
    sprintf(valuenum,"%.17lG",value);
#ifdef UNITENABLE  
  string unitstr = unitprint(MKS);
  if (unitstr.size() == 0)   return(string(valuenum));
  else return(string("(") + string(valuenum) + " " + unitstr + ")");
#else
  return(string(valuenum));
#endif
}

string physvarptr::getInfix() const {
  if (canonvars == (vector<physvar*>*)NULL) 
    return string("no physvar list");
  if (varindex < canonvars->size())
    return (*canonvars)[varindex]->clipsname; 
  else
    return string("physvarptr points to index greater than list size");
}

/************************************************************************
 * solprint of an assignment statement (ie. physvar = numval) returns a	*
 *	string suitable for passing to the help system, in the form	*
 *		(SVAR physvarname number units )   forhelp = false	*
 *      or	(= |physvarname| (DNUM number |units|))  forhelp = true	*
 *  If the physvar has prefUnit and it is consistent with numval's	*
 *	the value is converted to the prefUnit and output as number	*
 *  If the physvar does not have preferred units, value is in SI units	*
 *	and units is taken from first matching element in units.h	*
 *  If the prefUnit and the numval are inconsistent, throws exception	*
 *  Since 4/14/01, also enters SI value in numsols, which better 	*
 *	already exist and be big enough!				*
 ************************************************************************/
string binopexp::solprint(bool forhelp) const {
  string unitstr;

  if ( op->opty != equalse)
    throw(string("Tried to write a solution that is not an equation"));
  if (lhs->etype != physvart)
    throw(string("Tried to write a solution with lhs not a variable"));
  int varidx = ((physvarptr *)lhs)->varindex;
  if (rhs->etype != numval)
    throw(string("Tried to write a solution with rhs not a value"));
  DBG(cout << "Solprint on " << getInfix() << endl;);
  double value = ((numvalexp *)rhs)->value;
  if ((numsols == 0L) || (numsols == (vector<double> *)NULL))
    throw string("solprint called without numsols existing");
  if (numsols->size() <= varidx)
    throw string("solprint called with numsols too small");
  (*numsols)[varidx] = value;
  if ((*canonvars)[varidx]->prefUnit != "") {
    unitstr = (*canonvars)[varidx]->prefUnit;
    DBG(cout << "Solprint got prefUnit " << unitstr << endl;);
    numvalexp * denom = getfromunits(unitstr);
    DBG(cout << "That unitstr means " << denom->getInfix() << endl;);
    if (!(((numvalexp *)rhs)->MKS == denom->MKS))
      throw(string(getInfix()) + " inconsistent with preferred units for "
	    + (*canonvars)[varidx]->clipsname);
    value = value / denom->value;
    denom->destroy();
  }
  else {
    DBG(cout << "Solprint got no prefUnit " << endl;);
    dimens dim = ((numvalexp *)rhs)->MKS;
    unitstr = unitprint(dim);
    DBG(cout << "Solprint: manufactured unitstr " << unitstr << endl;);
  }

  // WARNING:  This code is repeated three times in this file
  int q;
  char valuenum[30];
  // don't truncate nonzero numbers near zero
  if ((value==0. || fabs(value)>0.5) && lookslikeint(value,q)) 
    sprintf(valuenum,"%d",q);
  else if ((fabs(value) < 1.) && (fabs(value)> 0.001))
    sprintf(valuenum,"%.17lf",value);
  else
    sprintf(valuenum,"%.17lG",value);
  if (forhelp)
  return(string("(= |") 
	 + (*canonvars)[varidx]->clipsname
	 + "| (DNUM " + string(valuenum) + " |" + unitstr + "|))");
  else   return(string("(SVAR ") 
	 + (*canonvars)[varidx]->clipsname
	 + " " + string(valuenum) + " " + unitstr + " )");
}

string binopexp::getInfix() const {
  DBG(cout << "getInfix on binop" << endl);
  
  return string(string("(") + lhs->getInfix() + string(" ") 
		+ op->printname + string(" ") + rhs->getInfix() + string(")"));
}


string functexp::getInfix() const {
  DBG(cout << "getInfix on functexp" << endl);
  return string(string("(") + f->printname + string(" (") 
		+ arg->getInfix() + string("))"));
}


string n_opexp::getInfix() const {
  int k;
  string ans = "( ";

  DBG(cout << "getInfix on n_op" << endl);
  if (this->args->size() == 0) {
    ans.append( op->printname + ")");
    return ans;
  }
  for (k = 0; k+1 < this->args->size(); k++)
    ans.append((*(this->args))[k]->getInfix() + " " + op->printname + " ");
  ans.append((*(this->args))[k]->getInfix() + ")");

  return ans;	 
}


/************************************************************************
 * expr::pretty(indent)							*
 *	prints out tree structure of expression, with indent spaces	*
 *	from left margin. Not used. Differs from dbgprint in that the	*
 *	latter names the kind of node, and spells out the units for	*
 *	each node							*
 ************************************************************************/
void numvalexp::pretty(int indent)
{
  int q;
  char valuenum[17];
  // don't truncate nonzero numbers near zero
  if ((value==0. || fabs(value)>0.5) && lookslikeint(value,q))
    sprintf(valuenum,"%d",q);
  else sprintf(valuenum," %14.8lf ",value);
  cout << string(indent,' ') + valuenum << endl;
}

void physvarptr::pretty(int indent)
{
  if (canonvars == (vector<physvar *> *) NULL) 
    { cout << "no physvar list" << endl; return; }
  if (varindex < canonvars->size()) {
  cout << string(indent,' ') + (*canonvars)[varindex]->clipsname << endl;
  return; }
  else cout << "physvarptr points to index " << varindex 
	    << "greater than list size" << canonvars->size() << endl;
}

void binopexp::pretty(int indent)
{
  cout << string(indent,' ') + op->printname << endl;
  lhs->pretty(indent+2);
  rhs->pretty(indent+2);
}

void functexp::pretty(int indent)
{
  cout << string(indent,' ') + f->printname << endl;
  arg->pretty(indent+2);
}
void n_opexp::pretty(int indent)
{
  int k;
  cout << string(indent,' ') + op->printname << endl;
  for (k=0;k<this->args->size();k++)
    (*(this->args))[k]->pretty(indent+2);
}

/************************************************************************
 * expr::dbgprint(indent)						*
 *	prints out tree structure of expression, with indent spaces	*
 *	from left margin. Differs from pretty in that dbgprint prints	*
 *	out the  names the kind of node, and spells out the units for	*
 *	each node.							*
 ************************************************************************/
void numvalexp::dbgprint(int indent)
{
  int q;
  char valuenum[17];
  // don't truncate nonzero numbers near zero
  if ((value==0. || fabs(value)>0.5) && lookslikeint(value,q))
    sprintf(valuenum,"%d",q);
  else sprintf(valuenum," %14.8lf ",value);
  cout << string(indent,' ') + "numval:  " + valuenum + "\t" + 
    MKS.print() << endl;
}

void physvarptr::dbgprint(int indent)
{
  if (canonvars == (vector<physvar *> *) NULL) 
    { cout << "no physvar list" << endl; return;  }
  if (varindex < canonvars->size()) {
  cout << string(indent,' ') + "physvar: " + (*canonvars)[varindex]->clipsname 
    + "\t" + MKS.print() << endl;
  return;
  }
  else cout << "physvarptr points to index " << varindex 
	    << "greater than list size" << canonvars->size() << endl;
}

void binopexp::dbgprint(int indent)
{
  cout << string(indent,' ') + "binop   " +  op->printname 
    + "\t" + MKS.print()<< endl;
  lhs->dbgprint(indent+2);
  rhs->dbgprint(indent+2);
}

void functexp::dbgprint(int indent)
{
  cout << string(indent,' ') + "funct:  " + f->printname 
     + "\t" + MKS.print() << endl;
  arg->dbgprint(indent+2);
}
void n_opexp::dbgprint(int indent)
{
  int k;
  cout << string(indent,' ')  + "n_op:   " + op->printname 
    + "\t" + MKS.print()<< endl;
  for (k=0;k<this->args->size();k++)
    (*(this->args))[k]->dbgprint(indent+2);
}

/************************************************************************
 * getLisp(withbarp) outputs expression in lisp form,                   *
 *	prefix form inside parentheses                                  *
 * if withbarp, places vertical bars before and after variable names    *
 *      and units                                                       *
 ************************************************************************/
string numvalexp::getLisp(bool withbarp) const {
  DBG( cout << "getLisp on numval" << endl; );

  // WARNING:  This code is repeated three times in this file
  int q;
  char valuenum[30];
  // don't truncate nonzero numbers near zero
  if ((value==0. || fabs(value)>0.5) && lookslikeint(value,q))
    sprintf(valuenum,"%d",q);
  else if ((fabs(value) < 1.) && (fabs(value)> 0.001))
    sprintf(valuenum,"%.17lf",value);
  else
    sprintf(valuenum,"%.17lG",value);
#ifdef UNITENABLE  
  string unitstr = unitprint(MKS);
  if (unitstr.size() == 0)   return(string("( ") +valuenum + " )");
  else return(string("(DNUM ") + string(valuenum) + 
	      ((withbarp) ? " |" + unitstr + "|)" : " " + unitstr + ")"));
#else
  return(string(valuenum));
#endif
}


string physvarptr::getLisp(bool withbarp) const {
  if (canonvars == (vector<physvar*>*)NULL) 
    return string("no physvar list");
  if (varindex < canonvars->size()) {
    if (withbarp)
      return (string("|") + (*canonvars)[varindex]->clipsname +"|"); 
    else return ( (*canonvars)[varindex]->clipsname ); 
  }
  else
    return string("physvarptr points to index greater than list size");
}


string binopexp::getLisp(bool withbarp) const {
  DBG(cout << "getLisp on binop" << endl;);
  return string(string("(")+ op->printname + string(" ") 
    + lhs->getLisp(withbarp) + string(" ") + rhs->getLisp(withbarp) 
		+ string(")"));
}


string functexp::getLisp(bool withbarp) const {
  DBG( cout << "getLisp on functexp" << endl; );
  return string(string("(") + f->printname + string(" ") 
		+ arg->getLisp(withbarp) + string(")"));
}


string n_opexp::getLisp(bool withbarp) const {
  DBG( cout << "getLisp on n_op" << endl;);
  int k;
  string ans = "(";
ans.append( op->printname + " ");
  for (k = 0; k+1 < this->args->size(); k++)
    ans.append((*(this->args))[k]->getLisp(withbarp) + " ");
  ans.append((*(this->args))[k]->getLisp(withbarp) + ")");
  return ans;
}

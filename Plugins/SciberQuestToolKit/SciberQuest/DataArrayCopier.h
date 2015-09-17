/*
 * Copyright 2012 SciberQuest Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *  * Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 *  * Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 *  * Neither name of SciberQuest Inc. nor the names of any contributors may be
 *    used to endorse or promote products derived from this software without
 *    specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHORS OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
#ifndef __DataArrayCopier_h
#define __DataArrayCopier_h

#include "IdBlock.h" // for IdBlock

#include "vtkType.h"

class vtkDataArray;

/// Copy id ranges from one vtk data array to another of the same type.
/**
Copy id ranges from one vtk data array to another of the
same type. Abstract interface to templated data array copier.
This class hides the template types from the compiler so that
we can have stl collections of aggregate coppiers.
*/
class DataArrayCopier
{
public:
  virtual ~DataArrayCopier(){}

  /**
  Initialize the copier for transfers from the given array
  to a new array of the same type and name. Initializes
  both input and output arrays.
  */
  virtual void Initialize(vtkDataArray *in)=0;

  /**
  Set the array to copy from.
  */
  virtual void SetInput(vtkDataArray *in)=0;
  virtual vtkDataArray *GetInput()=0;

  /**
  Set the array to copy to.
  */
  virtual void SetOutput(vtkDataArray *out)=0;
  virtual vtkDataArray *GetOutput()=0;

  /**
  Copy the range from the input array to the end of then
  output array.
  */
  virtual void Copy(IdBlock &ids)=0;
  virtual void Copy(vtkIdType id)=0;
};

#endif

// VTK-HeaderTest-Exclude: DataArrayCopier.h

#ifndef __SHADERS_H
#define __SHADERS_H

inline bool _CheckGLSLShaderCompile(GLuint shader, const char* file)
{
	int success;
	int infologLength = 0;
	int charsWritten = 0;
    char *infoLog;

	glGetObjectParameterivARB(shader, GL_COMPILE_STATUS, &success);
	glGetObjectParameterivARB(shader, GL_INFO_LOG_LENGTH,&infologLength);
	if(infologLength>0)
	{
	    infoLog = (char *)malloc(infologLength);
	    glGetInfoLogARB(shader, infologLength, &charsWritten, infoLog);
	}
	if(success!=GL_TRUE)
	{
	    // something went wrong
	    printf("GLSL ERROR: Compile error in shader %s\n", file);
		printf("%s\n",infoLog);
		free(infoLog);
		return FALSE;
	}
#ifdef _SHADERVERBOSE
	if(infologLength>1)
	{
	    // nothing went wrong, just warnings or messages
	    printf("GLSL WARNING: Compile log for shader %s\n", file);
	    printf("%s\n",infoLog);
	}
#endif
	if(infologLength>0)
	{
	    free(infoLog);
	}
	return TRUE;
}

inline bool _CheckGLSLProgramLink(GLuint program)
{
	int success;
	glGetObjectParameterivARB(program, GL_LINK_STATUS, &success);
	if(success!=GL_TRUE)
	{
		// Something went Wrong
		int infologLength = 0;
		int charsWritten = 0;
		char *infoLog;
		glGetObjectParameterivARB(program, GL_INFO_LOG_LENGTH,&infologLength);
		if (infologLength > 0)
	    {
	        infoLog = (char *)malloc(infologLength);
	        glGetInfoLogARB(program, infologLength, &charsWritten, infoLog);
			printf("OPENGL ERROR: Program link Error");
			printf("%s\n",infoLog);
	        free(infoLog);
	    }
		return FALSE;
	}
	return TRUE;
}

inline bool _CheckGLSLProgramValid(GLuint program)
{
	int success;
	glGetObjectParameterivARB(program, GL_VALIDATE_STATUS, &success);
	if(success!=GL_TRUE)
	{
		// Something went Wrong
		int infologLength = 0;
		int charsWritten = 0;
		char *infoLog;
		glGetObjectParameterivARB(program, GL_INFO_LOG_LENGTH,&infologLength);
		if (infologLength > 0)
	    {
	        infoLog = (char *)malloc(infologLength);
	        glGetInfoLogARB(program, infologLength, &charsWritten, infoLog);
			printf("OPENGL ERROR: Program Validation Failure");
			printf("%s\n",infoLog);
	        free(infoLog);
	    }
		return FALSE;
	}
	return TRUE;
}

#ifdef _DEBUG

#define CHECKGL( GLcall )                               		\
    GLcall;                                             		\
    if(!_CheckGL_Error( #GLcall, __FILE__, __LINE__))     		\
    exit(-1);

#define CHECKGLSLCOMPILE( Shader, file )						\
	if(!_CheckGLSLShaderCompile( Shader , file))				\
	exit(-1);

#define CHECKGLSLLINK( Program )								\
	if(!_CheckGLSLProgramLink( Program ))						\
	exit(-1);

#define CHECKGLSLVALID( Program )								\
	glValidateProgramARB( Program );								\
	if(!_CheckGLSLProgramValid( Program ))						\
	exit(-1);

#else

#define CHECKGL( GLcall)        \
    GLcall;

#define CHECKGLSLCOMPILE( Shader, file )

#define CHECKGLSLLINK( Program )

#define CHECKGLSLVALID( Program )

#endif



#endif

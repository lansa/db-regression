
/* SQLINES DEMO *** Table [dbo].[VTLI0036D]    Script Date: 2/2/2024 4:08:28 AM ******/
/* SET ANSI_NULLS ON */
GO

/* SET QUOTED_IDENTIFIER ON */
GO


CREATE TABLE [VTLI0036E](
	[V_SQA_ID] int NOT NULL,
	[V_SQA_NAME] nvarchar(50) NULL,
	[V_SQA_SURNAME] char(10) NULL,
	[V_SQA_LASTNAME] nchar(10) NULL,
	[V_SQA_DATE] datetime NULL,
	[V_SQA_SALARY] float NULL,
	[V_SQA_ACTIVE] bit NULL,
	[V_SQA_DESC] text NULL,
	[V_SQA_TAG] uniqueidentifier NULL,
	[V_SQA_TIME] time NULL,
	[V_SQA_RAWDATA] binary(50) NULL,
	[V_SQA_DATA] varchar(50) NULL,
	[V_SQA_CODE] numeric(18, 0) NULL,
	[V_SQA_XML] xml NULL,
 CONSTRAINT [PK_VTLI0036E] PRIMARY KEY 
(
	[V_SQA_ID] ASC
) 
)  
GO
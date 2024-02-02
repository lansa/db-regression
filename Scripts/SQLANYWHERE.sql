USE [LANSA];
GO

/* SQLINES DEMO *** Table [dbo].[VTLI0036D]    Script Date: 2/2/2024 4:08:28 AM ******/
/* SET ANSI_NULLS ON */
GO

/* SET QUOTED_IDENTIFIER ON */
GO


CREATE TABLE [dbo].[VTLI0036E](
	[V_ID] int NOT NULL,
	[V_NAME] nvarchar(50) NULL,
	[V_SURNAME] char(10) NULL,
	[V_LASTNAME] nchar(10) NULL,
	[V_DATE] datetime NULL,
	[V_SALARY] float NULL,
	[V_ACTIVE] bit NULL,
	[V_DESC] text NULL,
	[V_TAG] uniqueidentifier NULL,
	[V_TIME] time(7) NULL,
	[V_RAWDATA] binary(50) NULL,
	[V_DATA] varchar(50) NULL,
	[V_CODE] numeric(18, 0) NULL,
	[V_XML] xml NULL,
 CONSTRAINT [PK_VTLI0036E] PRIMARY KEY 
(
	[V_ID] ASC
) 
) 
GO
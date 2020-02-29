--@TIPO_MOV, @COD_MAT,@LOTE, @QTD_MOV
--EXEC PROC_GERA_ESTOQUE 
--CRIACAO PROC_INTEGR_NF_ESTOQUE
--EXECUTE PROC_INTEGR_NF_ESTOQUE 10,'2017-01-30'
--SELECT * FROM NOTA_FISCAL
--SELECT * FROM NOTA_FISCAL_ITENS
--UPDATE NOTA_FISCAL SET INTEGRADA_SUP='N' WHERE NUM_NF='2'
--SELECT * FROM ESTOQUE
--SELECT * FROM ESTOQUE_LOTE
--SELECT * FROM ESTOQUE_MOV
ALTER PROCEDURE PROC_INTEGR_NF_ESTOQUE (@NUM_NF INT,@DATA_MOVTO DATE)

AS 
 BEGIN 
    SET NOCOUNT ON 
--DECLARANDO VARIAVEIS
DECLARE @TIP_MOV VARCHAR(1), --E ENTRADA, S-SAIDA
        @COD_MAT  VARCHAR(50), 
        @LOTE     VARCHAR(15), 
        @QTD  DECIMAL(10, 2),
		@ErrorState INT,
	    @i int,
        @TIP_NF CHAR(1),
		@COD_MAT_AUX INT,
		@QTD_LOTE DECIMAL(10,2),
		@QTD_ATEND DECIMAL(10,2),
		@SALDO DECIMAL(10,2),
		@SALDO_AUX DECIMAL(10,2),
		@TESTE CHAR(1),
		@Msg VARCHAR(40)
--ATRIBUINDO VALORES
        SET @i = 9
		SET @QTD_ATEND=0
		SET @SALDO=0
		
       
BEGIN TRANSACTION
--ESTRURA IF ELSE
--VERFICANDO SE EXISTE DOCUMENTO
	IF (SELECT COUNT(*) 
		FROM NOTA_FISCAL WHERE NUM_NF=@NUM_NF )=0
	BEGIN 
	    SET @ErrorState =1;
	END
--VERIFCANDO SE EXISTE E JA ESTA INTEGRADO
	ELSE IF (SELECT TOP 1 A.NUM_NF 
	FROM NOTA_FISCAL A WHERE A.NUM_NF=@NUM_NF AND A.INTEGRADA_SUP='S')=@NUM_NF
	BEGIN 
	     SET @ErrorState =2;
	END
--VERIFICANDO SE OPERACAO DE ENTRADA PARA EXCUTAR ENTRADA EM ESTOQUE
	ELSE IF (SELECT COUNT(*) 
		FROM NOTA_FISCAL A WHERE A.NUM_NF=@NUM_NF AND A.TIP_NF='E'
		AND A.INTEGRADA_SUP='N')=1
	BEGIN 
	    PRINT  'OPERACAO DE ENTRADA'
	BEGIN TRY
		DECLARE INTEGRA_ESTOQUE CURSOR FOR
			SELECT A.TIP_NF,B.COD_MAT,
			CONCAT(DATEPART(DAYOFYEAR,GETDATE()),'-',A.NUM_NF) LOTE,
			--COMPOSICAO CAMPO LOTE (DIA DO ANO MAIS NUMERO DA NF)
			B.QTD 
			FROM NOTA_FISCAL A
			INNER JOIN NOTA_FISCAL_ITENS B
			ON A.NUM_NF=B.NUM_NF
			WHERE A.NUM_NF=@NUM_NF
			AND A.INTEGRADA_SUP='N' --INTEGRA NOTAS N=NAO

			OPEN INTEGRA_ESTOQUE
			FETCH NEXT FROM INTEGRA_ESTOQUE
			INTO @TIP_MOV,@COD_MAT,@LOTE,@QTD

	WHILE @@FETCH_STATUS = 0 OR @@ERROR<>0
		BEGIN
	   --@TIPO_MOV, @COD_MAT,@LOTE, @QTD_MOV,@DATA_MOVTO
	   --EXECUTANDO PROCEDURE DE ESTOQUE COMO PARAMETROS DO CURSOR
			EXEC PROC_GERA_ESTOQUE @TIP_MOV, @COD_MAT,@LOTE, @QTD,@DATA_MOVTO
	
			FETCH NEXT FROM INTEGRA_ESTOQUE
			INTO @TIP_MOV,@COD_MAT,@LOTE,@QTD
        END --END WHILE
	 --ATUALIZANDO STATUS DE INTEGRAC�O NFE
CLOSE INTEGRA_ESTOQUE
DEALLOCATE INTEGRA_ESTOQUE
END TRY --END TRY
    BEGIN CATCH
        SET @ErrorState =3;
        print ''
        print 'Erro ocorreu!'
        print 'Mensagem: ' + ERROR_MESSAGE()
        print 'Procedure: ' + ERROR_PROCEDURE()
END CATCH	

END --END IF ELSE DE CONFERE NOTA DE ENTRADA NAO INTEGRADA

--VERIFICANDO SE OPERACAO DE SAIDA PARA EXCUTAR SAIDA EM ESTOQUE
	ELSE IF (SELECT COUNT(*) 
		FROM NOTA_FISCAL A WHERE A.NUM_NF=@NUM_NF AND A.TIP_NF='S'
		AND A.INTEGRADA_SUP='N')=1
	BEGIN 
	    PRINT  'OPERACAO DE SAIDA'
	BEGIN TRY
	DECLARE LE_NFE_VENDA CURSOR FOR
 
   SELECT A.NUM_NF,A.TIP_NF,B.COD_MAT,B.QTD
		FROM NOTA_FISCAL A
		INNER JOIN NOTA_FISCAL_ITENS B
	ON A.NUM_NF=B.NUM_NF
	WHERE A.INTEGRADA_SUP='N'
	AND A.NUM_NF=@NUM_NF
	AND A.TIP_NF='S'
	ORDER BY B.COD_MAT
	--LENDO CURSOR
OPEN LE_NFE_VENDA
FETCH NEXT FROM LE_NFE_VENDA
	--INSERINDO VALOR NA VARIAVEL
		INTO @NUM_NF,@TIP_NF,@COD_MAT,@QTD
	--INICIANDO REPETICAO
		WHILE @@FETCH_STATUS = 0 
		BEGIN
		 IF (SELECT QTD_SALDO FROM ESTOQUE WHERE COD_MAT=@COD_MAT)<@QTD
		 BEGIN 
		  SET @ErrorState=4
         END
		 ELSE 
		 BEGIN
		--APRENSENTANDO VALORES **INFORMATIVO
		SELECT @NUM_NF NOTA ,@TIP_NF TIP_NF,@COD_MAT COD_MAT,@QTD QTD
--DECLARANDO CURSOR PARA LER ESTOQUE COM MATERIAIS DA NOTA PARA BAIXA EM ESTOQUE
DECLARE INTEGRA_NFE_VENDA CURSOR FOR

	SELECT C.COD_MAT,C.QTD_LOTE,C.LOTE 
		FROM  ESTOQUE_LOTE C
		WHERE C.COD_MAT=@COD_MAT
		AND C.QTD_LOTE>0
	ORDER BY C.COD_MAT,C.LOTE
--ABRINDO CURSOR 
OPEN INTEGRA_NFE_VENDA
		FETCH NEXT FROM INTEGRA_NFE_VENDA
--INSERINDO VALOR NAS VARIAVES
		INTO @COD_MAT,@QTD_LOTE,@LOTE 
--ATRIBUNDO VALOR AS VARIAVEIS		
		SET @SALDO=@QTD;
		SET @SALDO_AUX=@SALDO

		WHILE @@FETCH_STATUS = 0 
			BEGIN
--VERIFICA�OES DE TROCA DE MATERIAL
			  IF @COD_MAT_AUX<>@COD_MAT 
			  BEGIN 
				--SET @QTD_PED_AUX=0
				SET @QTD_ATEND=0
				SET @SALDO=@QTD;
			  END
--VERIFICACOES DE SALDO		 
			  IF @SALDO<=0
			  BEGIN 
			  SET @QTD_ATEND=0
			  END
--ESTRUTURA  DE VERIFICAO DE QUANTIDADE PEDIDO SALDO LOTE E SALDO PEDIDO
			  IF  @SALDO_AUX>=@QTD_LOTE
			  BEGIN 
			      SET  @QTD_ATEND=@QTD_ATEND+@QTD_LOTE
				  SET  @SALDO=@SALDO-@QTD
				  SET  @SALDO_AUX=@SALDO_AUX-@QTD_LOTE
				  SET @TESTE='1'
				  
			  END

			  ELSE IF  @SALDO_AUX<@QTD_LOTE
			  BEGIN 
			  SET  @SALDO=@SALDO-(@QTD-@QTD_LOTE)
			  SET  @QTD_ATEND=@QTD_ATEND+@SALDO_AUX
			  SET  @SALDO_AUX=@SALDO_AUX-@QTD_ATEND
			  SET @TESTE='2'
			  END

		--IF PARA INSERIR APENAS RETORNO COM SALDO>=0 E QTD_ATEND>0  

         IF @SALDO_AUX>=0 AND @QTD_ATEND>0
	      BEGIN
			  SELECT @NUM_NF NUM_NF,@TIP_NF TIP_NF ,@COD_MAT COD_MAT,@QTD QTD,
			         @QTD_LOTE QTD_LOTE,@LOTE LOTE,
		             @QTD_ATEND QTD_ATEND,@SALDO_AUX SD_AUX,@TESTE TESTE
		--EXCUTANDO PROCEDURE DE MOV ESTOQUE DENTRO DO IF, RECEBENDO VARIAVEIS
		EXEC PROC_GERA_ESTOQUE @TIP_NF, @COD_MAT,@LOTE, @QTD_ATEND,@DATA_MOVTO
		--ATRIBUINDO VALOR VARIAVEL 
		SET @COD_MAT_AUX=@COD_MAT;
	    END
		--LENDO PROXIMA LINHA DO CURSO
		FETCH NEXT FROM INTEGRA_NFE_VENDA
	    INTO @COD_MAT,@QTD_LOTE,@LOTE 
		END	
	--FECHANDO CURSO
	CLOSE INTEGRA_NFE_VENDA
	--DESALOCANDO CURSOR
    DEALLOCATE INTEGRA_NFE_VENDA
  --LENDO PROXIMA LINHA DO CURSOR
  END --FIM DO ELSE QUE VERIFICA ESTOQUE
  FETCH NEXT FROM LE_NFE_VENDA
		INTO @NUM_NF,@TIP_NF,@COD_MAT,@QTD
 --ATUALIZANDO NOTA FISCAL COMO INTEGRADA
 --UPDATE NOTA_FISCAL SET INTEGRADA_SUP='S' WHERE NUM_NF=@NUM_NF;
  
  END
  

  --FECHANDO CURSOR
  CLOSE LE_NFE_VENDA
  --DESALOCANDO CURSOR
  DEALLOCATE LE_NFE_VENDA
  END TRY --END TRY
    BEGIN CATCH
        SET @ErrorState =3;
        print ''
        print 'Erro ocorreu!'
        print 'Mensagem: ' + ERROR_MESSAGE()
        print 'Procedure: ' + ERROR_PROCEDURE()
  END CATCH	
  END --END IF ELSE DE CONFERE NOTA DE SAIDA NAO INTEGRADA

--ULTIMAS VERIFICACOES PARA COMMIT OU ROLLBACK
   IF @@ERROR <> 0 
		BEGIN
		  ROLLBACK
		  PRINT @@error
		  PRINT 'OPERACAO CANCELADA' 
		END
	ELSE IF @ErrorState=1
		BEGIN
		 ROLLBACK
		  PRINT 'DOCUMENTO NAO EXISTE'	
        END
	ELSE IF @ErrorState=2
		BEGIN
		 ROLLBACK
		  PRINT 'DOCUMENTO JA INTEGRADO'
        END
	ELSE IF @ErrorState=3
		BEGIN
		 ROLLBACK
		  PRINT 'ERRO NA PROCEDURE DE ESTOQUE'
        END
	ELSE IF @ErrorState=4
		BEGIN
		 ROLLBACK
		  PRINT 'SALDO INSUFICIENTE'
        END
	ELSE
		BEGIN
		    UPDATE NOTA_FISCAL SET INTEGRADA_SUP='S'  WHERE NUM_NF=@NUM_NF;
			COMMIT
		    PRINT 'INTEGRACAO CONCLUIDA'
		END 

END --FIM PROC

--SELECT * FROM NOTA_FISCAL
--UPDATE NOTA_FISCAL SET INTEGRADA_SUP='N'
/*
SELECT * FROM ESTOQUE
SELECT * FROM ESTOQUE_MOV
SELECT * FROM ESTOQUE_LOTE
*/

--SELECT * FROM PED_VENDAS_ITENS
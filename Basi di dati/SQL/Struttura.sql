DROP TABLE LUOGO;
DROP TABLE PERSONAINFOTO;
DROP TABLE SOGGETTIFOTO;
DROP TABLE SOGGETTIRICONOSCIUTI;
DROP TABLE PUBBLICAZIONE;
DROP TABLE PARTECIPAZIONE;
DROP TABLE BACHECACONDIVISA;
DROP TABLE BACHECAPERSONALE;
DROP TABLE FOTO;
DROP TABLE UTENTE;
DROP SEQUENCE genera_id_utente;
DROP SEQUENCE genera_id_bacheca_personale;
DROP SEQUENCE genera_id_bacheca_condivisa;
DROP SEQUENCE genera_id_foto;
PURGE RECYCLEBIN;
--CREAZIONE SEQUENCE PER AUTOINCREMENTI ID
--SEQUENCE CHE GENERA GLI ID PER UTENTE
CREATE SEQUENCE genera_id_utente
START WITH 1
INCREMENT BY 1
MINVALUE 1
NOCACHE;

--SEQUENCE CHE GENERA GLI ID PER BACHECAPERSONALE
CREATE SEQUENCE genera_id_bacheca_personale
START WITH 1
INCREMENT BY 1
MINVALUE 1
NOCACHE;

--SEQUENCE CHE GENERA GLI ID PER BACHECACONDIVISA
CREATE SEQUENCE genera_id_bacheca_condivisa
START WITH 1
INCREMENT BY 1
MINVALUE 1
NOCACHE;

--SEQUENCE CHE GENERA GLI ID PER FOTO
CREATE SEQUENCE genera_id_foto
START WITH 1
INCREMENT BY 1
MINVALUE 1
NOCACHE;










--CREAZIONE TABELLE
--CREAZIONE TABELLA UTENTE
CREATE TABLE UTENTE(
    IDUtente INTEGER DEFAULT ON NULL genera_id_utente.NEXTVAL PRIMARY KEY,
    Nome VARCHAR2(20) NOT NULL,
    Cognome VARCHAR2(20) NOT NULL,
    Email VARCHAR (100) NOT NULL UNIQUE,
    USR_Password VARCHAR(50) NOT NULL,
    CONSTRAINT check_validita_email CHECK (Email LIKE '_%@_%.__%')
);

--CREAZIONE TABELLA FOTO
CREATE TABLE FOTO(
    IDFoto INTEGER DEFAULT ON NULL genera_id_foto.NEXTVAL PRIMARY KEY,
    IDProprietario INTEGER NOT NULL,
    Dispositivo VARCHAR2(30) NOT NULL,
    isPrivate CHAR(1) NOT NULL,
    Dimensione FLOAT NOT NULL,
    DataOra DATE DEFAULT SYSDATE,
    CONSTRAINT fk_foto_utente FOREIGN KEY (IDProprietario) REFERENCES UTENTE(IDUtente)
);

--CREAZIONE TABELLA BACHECAPERSONALE
CREATE TABLE BACHECAPERSONALE(
    CodBP INTEGER DEFAULT ON NULL genera_id_bacheca_personale.NEXTVAL PRIMARY KEY,
    IDFoto INTEGER NOT NULL UNIQUE,
    IDProprietario INTEGER NOT NULL,
    CONSTRAINT fk_bp_foto FOREIGN KEY (IDFoto) REFERENCES FOTO(IDFoto),
    CONSTRAINT fk_bp_utente FOREIGN KEY (IDProprietario) REFERENCES UTENTE(IDUtente),
    CONSTRAINT uc_bachecapersonale UNIQUE (CodBP, IDProprietario)
);

--CREAZIONE TABELLA BACHECACONDIVISA
CREATE TABLE BACHECACONDIVISA(
    CodBC INTEGER DEFAULT ON NULL genera_id_bacheca_condivisa.NEXTVAL PRIMARY KEY,
    NomeBC VARCHAR2(40) NOT NULL UNIQUE,
    CONSTRAINT uc_bachecacondivisa UNIQUE (CodBC, NomeBC)
);

--CREAZIONE TABELLA PARTECIPAZIONE
CREATE TABLE PARTECIPAZIONE(
    IDUtente INTEGER NOT NULL,
    CodBC INTEGER NOT NULL,
    CONSTRAINT uc_partecipazione UNIQUE (IDUtente, CodBC)
);

--CREAZIONE TABELLA PUBBLICAZIONE
CREATE TABLE PUBBLICAZIONE(
    IDFoto INTEGER NOT NULL,
    CodBC INTEGER NOT NULL,
    CONSTRAINT uc_pubblicazione UNIQUE (IDFoto, CodBC)
);

--CREAZIONE TABELLA SOGGETTIRICONOSCIUTI
CREATE TABLE SOGGETTIRICONOSCIUTI(
    Soggetto VARCHAR2(20) NOT NULL PRIMARY KEY,
    Categoria VARCHAR2(20) NOT NULL UNIQUE,
    CONSTRAINT uc_soggetto UNIQUE (Soggetto, Categoria)
);

--CREAZIONE TABELLA SOGGETTIFOTO
CREATE TABLE SOGGETTIFOTO(
    IDFoto INTEGER NOT NULL,
    Soggetto VARCHAR2(20) NOT NULL,
    CONSTRAINT fk_soggettifoto_foto FOREIGN KEY (IDFoto) REFERENCES FOTO(IDFoto),
    CONSTRAINT fk_soggettifoto_soggettiriconosciuti FOREIGN KEY (Soggetto) REFERENCES SOGGETTIRICONOSCIUTI(Soggetto),
    CONSTRAINT uc_soggettifoto UNIQUE (IDFoto, Soggetto)
);

--CREAZIONE TABELLA PERSONAINFOTO
CREATE TABLE PERSONAINFOTO(
    IDUtente INTEGER NOT NULL,
    IDFoto INTEGER NOT NULL,
    CONSTRAINT fk_personainfoto_utente FOREIGN KEY (IDUtente) REFERENCES UTENTE(IDUtente),
    CONSTRAINT fk_personainfoto_foto FOREIGN KEY (IDFoto) REFERENCES FOTO(IDFoto),
    CONSTRAINT uc_personainfoto UNIQUE (IDUtente, IDFoto)
);

--CREAZIONE TABELLA LUOGO
CREATE TABLE LUOGO(
    IDFoto INTEGER NOT NULL,
    Citta VARCHAR2(30) DEFAULT ON NULL 'N/A',
    Latitudine INTEGER,
    Longitudine INTEGER,
    CONSTRAINT fk_luogo_foto FOREIGN KEY (IDFoto) REFERENCES FOTO(IDFoto)
);










--CREAZIONE TRIGGER
--Trigger che all'inserimento di una istanza nella tabella FOTO viene automaticamente inserita nella bacheca personale del proprietario
CREATE OR REPLACE TRIGGER tr_insert_bp
BEFORE INSERT ON FOTO
FOR EACH ROW
DECLARE
curr INTEGER;
BEGIN
    
    SELECT CodBP INTO curr
    FROM FOTO JOIN BACHECAPERSONALE ON FOTO.IDFoto = BACHECAPERSONALE.IDFoto
    WHERE FOTO.IDFoto = :NEW.IDFoto;

    IF(curr IS NOT NULL)
    THEN
        INSERT INTO BACHECAPERSONALE (CodBP, IDFoto, IDProprietario)
        VALUES (curr, :NEW.IDFoto , :NEW.IDProprietario);

    ELSE
        INSERT INTO BACHECAPERSONALE (IDFoto, IDProprietario)
        VALUES (:NEW.IDFoto , :NEW.IDProprietario);

    END IF;

END tr_insert_bp;
/

--Trigger che non permette di pubblicare una foto in una bacheca a cui non si � sottoscritti (partecipa)
CREATE OR REPLACE TRIGGER tr_partecipazione_privacy
AFTER INSERT ON PUBBLICAZIONE
FOR EACH ROW
DECLARE
id_check INTEGER;
privat CHAR(1);
partecipazione_mancante EXCEPTION;
foto_privata EXCEPTION;
partecipazione_mancante_foto_privata EXCEPTION;

BEGIN

    SELECT PARTECIPAZIONE.IDUtente INTO id_check
     FROM PUBBLICAZIONE JOIN FOTO ON PUBBLICAZIONE.IDFoto = FOTO.IDFoto JOIN UTENTE ON IDProprietario = IDUtente JOIN PARTECIPAZIONE ON UTENTE.IDUtente = PARTECIPAZIONE.IDUtente
     WHERE PARTECIPAZIONE.CodBC = :NEW.CodBC AND FOTO.IDFoto = :NEW.IDFoto;

    SELECT FOTO.isPrivate INTO privat
     FROM PUBBLICAZIONE JOIN FOTO ON PUBBLICAZIONE.IDFoto = FOTO.IDFoto
     WHERE FOTO.IDFoto = :NEW.IDFoto;

    IF (id_check IS NULL AND privat = 'Y')
    THEN
        RAISE partecipazione_mancante_foto_privata;

    ELSE IF (privat = 'Y')
    THEN
        RAISE foto_privata;

    ELSE IF (id_check IS NULL)
    THEN
        RAISE partecipazione_mancante;

    END IF;
    END IF;
    END IF;

        EXCEPTION
            WHEN partecipazione_mancante_foto_privata THEN
            RAISE_APPLICATION_ERROR(-20001, '-Una foto privata non può essere condivisa\-Devi partecipare alla bacheca prima di pubblicare la tua foto');
            WHEN foto_privata THEN
            RAISE_APPLICATION_ERROR(-20002, '-Una foto privata non può essere condivisa');
            WHEN partecipazione_mancante THEN
            RAISE_APPLICATION_ERROR(-20003, '-Devi partecipare alla bacheca prima di pubblicare la tua foto');

END tr_partecipazione_privacy;
/










--CREAZIONE FUNZIONI E PROCEDURE
--Funzione che recupera tutte le foto scattate nello stesso luogo
CREATE OR REPLACE FUNCTION foto_luogo_in_comune (IN_Citta LUOGO.Citta%TYPE)
RETURN VARCHAR2 AS
output VARCHAR2(2000);
curr VARCHAR2(100);
CURSOR C1 IS SELECT IDFoto
             FROM LUOGO
             WHERE LUOGO.Citta = IN_Citta;
BEGIN
    OPEN C1;

    LOOP
    EXIT WHEN(C1%NOTFOUND);
    FETCH C1 INTO curr;
    output := (output ||  curr || ',');
    curr := '';
    END LOOP;
    RTRIM (output, ',');
    RETURN output;
END;
/

--Funzione che recupera tutte le foto che condividono lo stesso soggetto










--CREAZIONE VISTE
--Vista dei 3 luoghi più immortalati
CREATE OR REPLACE VIEW TOP3LUOGHI AS
    SELECT Citta, COUNT(IDFoto) AS Numero_Scatti
    FROM LUOGO
    GROUP BY Citta
    ORDER BY Numero_Scatti DESC
    FETCH FIRST 3 ROWS ONLY;

ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY hh24:mi';

COMMIT;
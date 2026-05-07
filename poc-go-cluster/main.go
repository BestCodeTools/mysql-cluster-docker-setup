package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	gosqlmysql "github.com/go-sql-driver/mysql"
	"github.com/pressly/goose/v3"
	gormmysql "gorm.io/driver/mysql"
	"gorm.io/gorm"
)

type clusterConfig struct {
	Host     string
	Port     int
	User     string
	Password string
	Database string
}

type clusterMessage struct {
	ID        uint64    `gorm:"column:id;primaryKey;autoIncrement"`
	Content   string    `gorm:"column:content;size:255;not null"`
	CreatedAt time.Time `gorm:"column:created_at;autoCreateTime"`
	UpdatedAt time.Time `gorm:"column:updated_at;autoUpdateTime"`
}

func (clusterMessage) TableName() string {
	return "go_cluster_messages"
}

func main() {
	config := loadConfig()
	log.Printf("Iniciando PoC Go contra %s:%d/%s.", config.Host, config.Port, config.Database)

	db, err := sql.Open("mysql", config.dsn())
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		log.Fatal(err)
	}

	if err := validateNdbEngine(db); err != nil {
		log.Fatal(err)
	}

	if err := runMigrations(db); err != nil {
		log.Fatal(err)
	}

	if err := runRawChecks(db); err != nil {
		log.Fatal(err)
	}

	if err := runGormChecks(config); err != nil {
		log.Fatal(err)
	}

	log.Println("PoC Go validada com sucesso.")
}

func loadConfig() clusterConfig {
	return clusterConfig{
		Host:     getenv("DB_HOST", "127.0.0.1"),
		Port:     getenvInt("DB_PORT", 3306),
		User:     getenv("DB_USER", "cluster_app"),
		Password: getenv("DB_PASSWORD", "ClusterApp123!"),
		Database: getenv("DB_NAME", "cluster_poc"),
	}
}

func (config clusterConfig) dsn() string {
	dsnConfig := gosqlmysql.NewConfig()
	dsnConfig.Net = "tcp"
	dsnConfig.Addr = fmt.Sprintf("%s:%d", config.Host, config.Port)
	dsnConfig.User = config.User
	dsnConfig.Passwd = config.Password
	dsnConfig.DBName = config.Database
	dsnConfig.ParseTime = true
	dsnConfig.MultiStatements = true
	dsnConfig.AllowNativePasswords = true
	return dsnConfig.FormatDSN()
}

func validateNdbEngine(db *sql.DB) error {
	rows, err := db.Query("SHOW ENGINES")
	if err != nil {
		return err
	}
	defer rows.Close()

	for rows.Next() {
		var engine string
		var support string
		var comment sql.NullString
		var transactions sql.NullString
		var xa sql.NullString
		var savepoints sql.NullString
		if err := rows.Scan(&engine, &support, &comment, &transactions, &xa, &savepoints); err != nil {
			return err
		}

		if strings.EqualFold(engine, "NDBCLUSTER") && !strings.EqualFold(support, "NO") {
			log.Printf("Engine NDBCLUSTER disponivel (%s).", support)
			return nil
		}
	}

	return fmt.Errorf("engine NDBCLUSTER nao esta disponivel")
}

func runMigrations(db *sql.DB) error {
	log.Println("Executando migration com goose.")
	goose.SetDialect("mysql")
	migrationsDir := filepath.Join(".", "migrations")
	return goose.Up(db, migrationsDir)
}

func runRawChecks(db *sql.DB) error {
	log.Println("Executando CRUD com database/sql.")
	if _, err := db.Exec("DELETE FROM go_cluster_messages"); err != nil {
		return err
	}

	content := fmt.Sprintf("raw go em %s", time.Now().UTC().Format(time.RFC3339Nano))
	result, err := db.Exec("INSERT INTO go_cluster_messages (content) VALUES (?)", content)
	if err != nil {
		return err
	}

	insertedID, err := result.LastInsertId()
	if err != nil {
		return err
	}

	var loadedContent string
	if err := db.QueryRow(
		"SELECT content FROM go_cluster_messages WHERE id = ?",
		insertedID,
	).Scan(&loadedContent); err != nil {
		return err
	}

	if loadedContent != content {
		return fmt.Errorf("falha ao ler registro inserido via database/sql")
	}

	if _, err := db.Exec("DELETE FROM go_cluster_messages WHERE id = ?", insertedID); err != nil {
		return err
	}

	var count int
	if err := db.QueryRow(
		"SELECT COUNT(*) FROM go_cluster_messages WHERE id = ?",
		insertedID,
	).Scan(&count); err != nil {
		return err
	}

	if count != 0 {
		return fmt.Errorf("falha ao excluir registro via database/sql")
	}

	log.Printf("database/sql validado. id=%d", insertedID)
	return nil
}

func runGormChecks(config clusterConfig) error {
	log.Println("Executando CRUD com GORM.")

	gormDB, err := gorm.Open(gormmysql.Open(config.dsn()), &gorm.Config{})
	if err != nil {
		return err
	}

	if err := gormDB.Exec("DELETE FROM go_cluster_messages").Error; err != nil {
		return err
	}

	content := fmt.Sprintf("gorm em %s", time.Now().UTC().Format(time.RFC3339Nano))
	message := clusterMessage{Content: content}
	if err := gormDB.Create(&message).Error; err != nil {
		return err
	}

	var loaded clusterMessage
	if err := gormDB.First(&loaded, message.ID).Error; err != nil {
		return err
	}

	if loaded.Content != content {
		return fmt.Errorf("falha ao ler registro inserido via GORM")
	}

	if err := gormDB.Delete(&loaded).Error; err != nil {
		return err
	}

	var count int64
	if err := gormDB.Model(&clusterMessage{}).Where("id = ?", message.ID).Count(&count).Error; err != nil {
		return err
	}

	if count != 0 {
		return fmt.Errorf("falha ao excluir registro via GORM")
	}

	log.Printf("GORM validado. id=%d", message.ID)
	return nil
}

func getenv(key, fallback string) string {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	return value
}

func getenvInt(key string, fallback int) int {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}

	parsed, err := strconv.Atoi(value)
	if err != nil {
		return fallback
	}
	return parsed
}

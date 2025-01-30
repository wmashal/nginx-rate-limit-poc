package main

import (
	"encoding/json"
	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"log"
	"net/http"
	"os"
	"time"
)

type ServiceBinding struct {
	ID         string    `json:"id"`
	InstanceID string    `json:"instance_id"`
	ServiceID  string    `json:"service_id"`
	PlanID     string    `json:"plan_id"`
	CreatedAt  time.Time `json:"created_at"`
}

type ServiceOffering struct {
	ID          string    `json:"id"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type ServicePlan struct {
	ID          string    `json:"id"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	Free        bool      `json:"free"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type ServiceInstance struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	ServiceID string    `json:"service_id"`
	PlanID    string    `json:"plan_id"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// API Response structure
type APIResponse struct {
	Items      interface{} `json:"items"`
	TotalItems int         `json:"total_items"`
}

// Error Response structure
type ErrorResponse struct {
	Error       string `json:"error"`
	Description string `json:"description"`
}

func main() {
	r := mux.NewRouter()

	// Service Bindings endpoints
	r.HandleFunc("/v1/service_bindings", getServiceBindings).Methods("GET")
	r.HandleFunc("/v1/service_bindings", createServiceBinding).Methods("POST")
	r.HandleFunc("/v1/service_bindings/{id}", getServiceBinding).Methods("GET")
	r.HandleFunc("/v1/service_bindings/{id}", deleteServiceBinding).Methods("DELETE")

	// Service Offerings endpoints
	r.HandleFunc("/v1/service_offerings", getServiceOfferings).Methods("GET")
	r.HandleFunc("/v1/service_offerings", createServiceOffering).Methods("POST")
	r.HandleFunc("/v1/service_offerings/{id}", getServiceOffering).Methods("GET")
	r.HandleFunc("/v1/service_offerings/{id}", deleteServiceOffering).Methods("DELETE")

	// Service Plans endpoints
	r.HandleFunc("/v1/service_plans", getServicePlans).Methods("GET")
	r.HandleFunc("/v1/service_plans", createServicePlan).Methods("POST")
	r.HandleFunc("/v1/service_plans/{id}", getServicePlan).Methods("GET")
	r.HandleFunc("/v1/service_plans/{id}", deleteServicePlan).Methods("DELETE")

	// Service Instances endpoints
	r.HandleFunc("/v1/service_instances", getServiceInstances).Methods("GET")
	r.HandleFunc("/v1/service_instances", createServiceInstance).Methods("POST")
	r.HandleFunc("/v1/service_instances/{id}", getServiceInstance).Methods("GET")
	r.HandleFunc("/v1/service_instances/{id}", deleteServiceInstance).Methods("DELETE")

	// Add health endpoint
	r.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	}).Methods("GET")

	port := os.Getenv("PORT")
	//if port == "" {
	//	port = "8899" // fallback to original port if not set
	//}

	log.Printf("Starting Service Manager Mock V1 on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, r))

}

// Helper functions
func respondWithJSON(w http.ResponseWriter, code int, payload interface{}) {
	response, err := json.Marshal(payload)
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, "Internal Server Error", err.Error())
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	w.Write(response)
}

func respondWithError(w http.ResponseWriter, code int, message string, description string) {
	respondWithJSON(w, code, ErrorResponse{
		Error:       message,
		Description: description,
	})
}

// Service Bindings Handlers
func getServiceBindings(w http.ResponseWriter, r *http.Request) {
	bindings := []ServiceBinding{
		{
			ID:         uuid.New().String(),
			InstanceID: uuid.New().String(),
			ServiceID:  uuid.New().String(),
			PlanID:     uuid.New().String(),
			CreatedAt:  time.Now(),
		},
	}

	response := APIResponse{
		Items:      bindings,
		TotalItems: len(bindings),
	}
	respondWithJSON(w, http.StatusOK, response)
}

func createServiceBinding(w http.ResponseWriter, r *http.Request) {
	var binding ServiceBinding
	if err := json.NewDecoder(r.Body).Decode(&binding); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request payload", err.Error())
		return
	}

	binding.ID = uuid.New().String()
	binding.CreatedAt = time.Now()

	respondWithJSON(w, http.StatusCreated, binding)
}

func getServiceBinding(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	binding := ServiceBinding{
		ID:         vars["id"],
		InstanceID: uuid.New().String(),
		ServiceID:  uuid.New().String(),
		PlanID:     uuid.New().String(),
		CreatedAt:  time.Now(),
	}
	respondWithJSON(w, http.StatusOK, binding)
}

func deleteServiceBinding(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusNoContent)
}

// Service Offerings Handlers
func getServiceOfferings(w http.ResponseWriter, r *http.Request) {
	offerings := []ServiceOffering{
		{
			ID:          uuid.New().String(),
			Name:        "sample-service",
			Description: "A sample service offering",
			CreatedAt:   time.Now(),
			UpdatedAt:   time.Now(),
		},
	}

	response := APIResponse{
		Items:      offerings,
		TotalItems: len(offerings),
	}
	respondWithJSON(w, http.StatusOK, response)
}

func createServiceOffering(w http.ResponseWriter, r *http.Request) {
	var offering ServiceOffering
	if err := json.NewDecoder(r.Body).Decode(&offering); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request payload", err.Error())
		return
	}

	offering.ID = uuid.New().String()
	offering.CreatedAt = time.Now()
	offering.UpdatedAt = time.Now()

	respondWithJSON(w, http.StatusCreated, offering)
}

func getServiceOffering(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	offering := ServiceOffering{
		ID:          vars["id"],
		Name:        "sample-service",
		Description: "A sample service offering",
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}
	respondWithJSON(w, http.StatusOK, offering)
}

func deleteServiceOffering(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusNoContent)
}

// Service Plans Handlers
func getServicePlans(w http.ResponseWriter, r *http.Request) {
	plans := []ServicePlan{
		{
			ID:          uuid.New().String(),
			Name:        "basic-plan",
			Description: "Basic service plan",
			Free:        true,
			CreatedAt:   time.Now(),
			UpdatedAt:   time.Now(),
		},
	}

	response := APIResponse{
		Items:      plans,
		TotalItems: len(plans),
	}
	respondWithJSON(w, http.StatusOK, response)
}

func createServicePlan(w http.ResponseWriter, r *http.Request) {
	var plan ServicePlan
	if err := json.NewDecoder(r.Body).Decode(&plan); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request payload", err.Error())
		return
	}

	plan.ID = uuid.New().String()
	plan.CreatedAt = time.Now()
	plan.UpdatedAt = time.Now()

	respondWithJSON(w, http.StatusCreated, plan)
}

func getServicePlan(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	plan := ServicePlan{
		ID:          vars["id"],
		Name:        "basic-plan",
		Description: "Basic service plan",
		Free:        true,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}
	respondWithJSON(w, http.StatusOK, plan)
}

func deleteServicePlan(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusNoContent)
}

// Service Instances Handlers
func getServiceInstances(w http.ResponseWriter, r *http.Request) {
	instances := []ServiceInstance{
		{
			ID:        uuid.New().String(),
			Name:      "test-instance",
			ServiceID: uuid.New().String(),
			PlanID:    uuid.New().String(),
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		},
	}

	response := APIResponse{
		Items:      instances,
		TotalItems: len(instances),
	}
	respondWithJSON(w, http.StatusOK, response)
}

func createServiceInstance(w http.ResponseWriter, r *http.Request) {
	var instance ServiceInstance
	if err := json.NewDecoder(r.Body).Decode(&instance); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request payload", err.Error())
		return
	}

	instance.ID = uuid.New().String()
	instance.CreatedAt = time.Now()
	instance.UpdatedAt = time.Now()

	respondWithJSON(w, http.StatusCreated, instance)
}

func getServiceInstance(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	instance := ServiceInstance{
		ID:        vars["id"],
		Name:      "test-instance",
		ServiceID: uuid.New().String(),
		PlanID:    uuid.New().String(),
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	respondWithJSON(w, http.StatusOK, instance)
}

func deleteServiceInstance(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusNoContent)
}

public with sharing class JiraIntegrationGetProjectsController {

    public ApexPages.StandardController controller;

    // CONSTRUCTOR
    public JiraIntegrationGetProjectsController(ApexPages.StandardController controller) {
        this.controller = controller;
    }

    // GET PROJECTS
    public Pagereference getProjects() {

        Map<String,Object> response = 
            JiraIntegrationRequest.getProjectsFromJira();
        if (response.containsKey(Jira.STATUS_CODE) &&
            response.containsKey(Jira.STATUS)) {
                // 200
                if (response.get(Jira.STATUS_CODE) ==  200 &&
                    response.get(Jira.STATUS) == Jira.OK) {
                        return new ApexPages.Action('{!list}').invoke();
                    }
                else {
                    // TODO: 404 500
                }
            }
        else {
            // TODO: not response
        }
        return controller.view();
    }

    // UPSERT PROJECTS
    public static Map<String,Object> upsertProjects(HttpResponse httpResponse) {

        Map<String,Object> response = new Map<String,Object>();
        Map<String,Jira_Project__c> idPerprojectsFromJira = getAndSetProjects(httpResponse);
        List<Jira_Project__c> projectsToUpsert = new List<Jira_Project__c>();    
        if (!idPerprojectsFromJira.isEmpty()) {
            projectsToUpsert = validateProjects(idPerprojectsFromJira);
        }
        else {
            response.put(Jira.STATUS_CODE, 404);
            response.put(Jira.STATUS, Jira.ERROR);
            response.put(Jira.DATA, 'No projects returned');
        }
        if (!projectsToUpsert.isEmpty()) {
            try {
                upsert projectsToUpsert;
                response.put(Jira.STATUS_CODE, 200);
                response.put(Jira.STATUS, Jira.OK);
            }
            catch (Exception ex) {
                response.put(Jira.STATUS_CODE, 500);
                response.put(Jira.STATUS, Jira.ERROR);
                response.put(Jira.DATA, ex.getMessage());
                System.debug(LoggingLevel.ERROR, ex.getMessage());
            }
        }
        return response;
    }

    // GET AND SET PROJECTS
    public static Map<String,Jira_Project__c> getAndSetProjects(HttpResponse httpResponse) {

        Map<String,Jira_Project__c> idPerProjectsFromJira = new Map<String,Jira_Project__c>();
        JiraGetProjectsResponse responseProjects = (JiraGetProjectsResponse)
            JSON.deserialize(httpResponse.getBody(), JiraGetProjectsResponse.class);
        for (JiraGetProjectsResponse.Project eachResProj : responseProjects.values) {
            Jira_Project__c project = new Jira_Project__c(
                Id__c = eachResProj.id,
                Key__c = eachResProj.key,
                Name = eachResProj.name
            );
            idPerProjectsFromJira.put(eachResProj.id, project);
        }
        return idPerProjectsFromJira;
    }

    // VALIDATE PROJECTS
    public static List<Jira_Project__c> validateProjects(Map<String,Jira_Project__c> idPerProjectsFromJira) {

        List<Jira_Project__c> projects = [
            SELECT Id,
                Id__c
            FROM Jira_Project__c
            WHERE Id__c IN : idPerProjectsFromJira.keySet()
        ];
        Map<String,Jira_Project__c> idPerProject = new Map<String,Jira_Project__c>();
        for (Jira_Project__c eachProj : projects) {
            idPerProject.put(eachProj.Id__c, eachProj);
        }
        List<Jira_Project__c> projectsToUpsert = new List<Jira_Project__c>();        
        for (Jira_Project__c eachProj : idPerProjectsFromJira.values()) {
            if (!idPerProject.containsKey(eachProj.Id__c)) {
                projectsToUpsert.add(eachProj);
            }
            else {
                Jira_Project__c project = idPerProjectsFromJira.get(eachProj.Id__c);
                project.Id = idPerProject.get(eachProj.Id__c).Id;
                projectsToUpsert.add(project);
            }
        }
        return projectsToUpsert;
    }
}
(("openshift/"
  . ((eglot-workspace-configuration
      . (:yaml (:schemas (:kubernetes "*.yaml"
				      :https://raw.githubusercontent.com/melmorabity/openshift-json-schemas/main/v4.14-local/_definitions.json "*.yaml"))))))
 ("ansible/"
  . ((eglot-workspace-configuration
      :ansible (:validation
		(:enabled t :lint (:enabled t)))))))

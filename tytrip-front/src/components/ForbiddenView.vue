<template>
  <div class="page">
    <el-result icon="warning" title="Accès refusé" sub-title="Vous n’avez pas les droits nécessaires pour accéder à cette page.">
      <template #extra>
        <el-button type="primary" @click="$router.push('/')">Retour à l’accueil</el-button>
      </template>
    </el-result>
  </div>
</template>
